---
name: docker-compose-depends-on-postgres-econnrefused-race
description: |
  Fix intermittent "Error: connect ECONNREFUSED 127.0.0.1:5432" from an app container
  right after `docker compose up`, even though DATABASE_URL points at `db:5432`.
  Use when: (1) first request after `docker compose up` fails with ECONNREFUSED 5432
  and succeeds 5-10 seconds later, (2) `docker compose ps` shows the db service
  `healthy` and the app `running` while connections are refused, (3) `docker compose
  config` shows `depends_on` expanded to `condition: service_started`, (4) in-container
  `net.connect(5432, 'db')` returns ERR ECONNREFUSED while DNS lookup of `db`
  succeeds. Covers Docker Compose v2 `depends_on` short-form semantics and
  `condition: service_healthy` gating for Postgres (and any healthchecked dependency).
author: Claude Code
version: 1.0.0
date: 2026-11-10
---

# Docker Compose depends_on Race Behind Intermittent Postgres ECONNREFUSED

## Problem

A Node API container starts connecting to Postgres before Postgres is actually
listening on its TCP port. Roughly 40% of `docker compose up` runs, the first
request to `localhost:3000/healthz` dies with `connect ECONNREFUSED 127.0.0.1:5432`;
waiting 5-10 seconds makes it work. Two things make this non-obvious:

- `depends_on` written as a bare list only means "the container process started",
  not "the healthcheck passed", so the defined `healthcheck` on the db service is
  never consulted.
- The error text says `127.0.0.1:5432` even though `DATABASE_URL` is
  `postgres://postgres:dev@db:5432/app`, which sends people hunting for a wrong
  host or a missing `DATABASE_URL`.

## Context / Trigger Conditions

- `Error: connect ECONNREFUSED 127.0.0.1:5432` with `at TCPConnectWrap.afterConnect [as oncomplete] (node:net:1637:16)`
- Failure is intermittent (about 40% of `up` runs) and self-heals after 5-10 seconds
- `docker compose ps` reports `db` as `healthy` and `api` as `running`
- `docker compose exec api printenv DATABASE_URL` shows the correct `db:5432` host
- `docker compose exec api node -e "require('dns').lookup('db',...)"` resolves fine (e.g. `172.20.0.2`)
- `docker compose exec api node -e "require('net').connect(5432,'db')..."` prints `ERR ECONNREFUSED`
- `docker compose config | grep -A4 depends_on` shows `condition: service_started`
- `docker compose logs db` shows `database system is ready to accept connections` **twice** (init-phase temporary instance plus the real start)
- Docker 27.3.1 / Docker Compose v2.29.7, `postgres:16.4`, Node app using the `pg` driver

## Solution

### Step 1: Prove the dependency is refused, not misaddressed

Check that DNS and config are innocent and that the port itself is closed, from
inside the app container:

```sh
docker compose exec api printenv DATABASE_URL
# postgres://postgres:dev@db:5432/app

docker compose exec api node -e "require('dns').lookup('db',(e,a)=>console.log(e,a))"
# null '172.20.0.2'

docker compose exec api node -e "require('net').connect(5432,'db').on('error',e=>console.log('ERR',e.code)).on('connect',()=>console.log('OK'))"
# ERR ECONNREFUSED
```

`ERR ECONNREFUSED` on a resolvable hostname means Postgres is not listening yet —
not a DNS, network, or credentials problem.

### Step 2: Confirm depends_on is not gating on health

```sh
docker compose config | grep -A4 depends_on
#     depends_on:
#       db:
#         condition: service_started
```

The short list form of `depends_on` expands to `condition: service_started`, which
waits only for the container process to exist. The `healthcheck` block on `db` is
defined but never referenced, so nothing waits for `pg_isready` to pass.

### Step 3: Gate the dependency on the healthcheck

```yaml
services:
  db:
    image: postgres:16.4
    environment:
      POSTGRES_PASSWORD: dev
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 2s
      timeout: 3s
      retries: 30
  api:
    build: .
    environment:
      DATABASE_URL: postgres://postgres:dev@db:5432/app
    depends_on:
      db:
        condition: service_healthy
    ports: ["3000:3000"]
```

Keep the `healthcheck` on the dependency — `condition: service_healthy` is useless
without one.

## Verification

1. Recreate the stack from scratch each round so the race window reappears:

```sh
for i in $(seq 30); do
  docker compose down -v >/dev/null 2>&1
  docker compose up -d >/dev/null 2>&1
  sleep 1
  curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/healthz
done | sort | uniq -c
```

2. Expected outcome: every round returns `200`:

```
     30 200
```

3. Confirm no connection errors were logged:

```sh
docker compose logs api | grep -c ECONNREFUSED
# 0
```

## Example

**Scenario**: `docker compose up` followed immediately by `curl localhost:3000/healthz`
on a Node API + `postgres:16.4` stack; the request fails about 40% of the time and
succeeds on retry a few seconds later.

**Before**:

```yaml
  api:
    depends_on:
      - db
```

```
api  | Error: connect ECONNREFUSED 127.0.0.1:5432
api  |     at TCPConnectWrap.afterConnect [as oncomplete] (node:net:1637:16)
```

**After**:

```yaml
  api:
    depends_on:
      db:
        condition: service_healthy
```

```
     30 200
```

## Notes

- Retries in the client are a mitigation, not a fix. Adding `connectionTimeoutMillis`
  plus 5 exponential-backoff retries still failed 3 out of 20 `up` runs; gate the
  dependency instead.
- `docker compose ps` showing `healthy` proves nothing about ordering: health state is
  reported per service, and nothing in `depends_on` short form reads it.
- A second `database system is ready to accept connections` line in `docker compose
  logs db` is expected: the Postgres image logs it once for the initialization-phase
  temporary instance and once for the real server start.
- Unverified claim about the `127.0.0.1` in the message: the `pg` driver appears to
  print the socket's local endpoint with the system errno text (read from
  `packages/pg/lib/connection.js`, `Error: connect ECONNREFUSED <localAddress>:<localPort>`).
  This was not measured, so treat "the address in the error is misleading" as an
  inference, and diagnose with an in-container `net.connect` probe rather than by
  reading the address in the error.
- Different root cause with the same error text: on another machine the identical
  compose stack failed on **every** request and never recovered. There the Postgres
  image had been swapped for a custom build whose `postgresql.conf` set
  `listen_addresses = 'localhost'`, so Postgres listened only on loopback inside its
  own network namespace and was unreachable from the `api` container;
  `condition: service_healthy` did not help because the healthcheck runs inside the
  db container and passes anyway. Discriminator: intermittent-and-self-healing means
  startup race (this skill); permanent failure means server bind/listen configuration.
- Not verified in this session: the Kubernetes equivalent (`readinessProbe` +
  `initContainer`), whether `restart: unless-stopped` also masks the race, and the
  effect of lowering `retries: 30` (with `interval: 2s`, up to 60 seconds before the
  dependency is declared unhealthy) on startup latency.
- Environment used: Docker 27.3.1, Docker Compose v2.29.7, `postgres:16.4`, Node
  `pg` driver.
