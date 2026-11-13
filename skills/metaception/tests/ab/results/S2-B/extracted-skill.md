---
name: compose-depends-on-service-healthy-postgres
description: |
  修复 docker compose 启动竞态：服务起来后首个请求报 `Error: connect ECONNREFUSED 127.0.0.1:5432`，根因是裸 `depends_on` 列表只等价于 `condition: service_started`，不等 Postgres healthcheck。技术栈 docker compose v2、`postgres:16.4`、Node.js `pg`。Use when: (1) `docker compose up` 后立刻请求偶发失败、等数秒即好, (2) 容器内 `printenv DATABASE_URL` 与 DNS 解析都正常, (3) 报错地址是 `127.0.0.1:5432` 而不是 `db:5432`, (4) 加连接重试只能压低失败率、不能根治。
author: Claude Code (claudeception-quad)
version: 1.0.0
date: 2026-11-10
---

# compose 启动竞态：depends_on 不等 healthcheck 导致 Postgres ECONNREFUSED

## Facts

| # | 事实 | 证据 | 复核命令 | 生效条件 | 记录日期 |
|---|------|------|----------|----------|----------|
| F1 | api 容器日志逐字输出 `Error: connect ECONNREFUSED 127.0.0.1:5432`，栈帧为 `at TCPConnectWrap.afterConnect [as oncomplete] (node:net:1637:16)` | 会话日志行：`Error: connect ECONNREFUSED 127.0.0.1:5432`（api 容器 stdout/stderr 原文） | `docker compose logs api` | docker compose v2 + Node.js `pg` 驱动 + postgres:16.4 | 2026-11-10 |
| F2 | `depends_on` 的裸列表写法展开后等价于 `condition: service_started`，即只保证 db 容器进程已启动 | `docker compose config` 输出 `depends_on: db: condition: service_started` | `docker compose config` | Docker Compose v2.29.7 | 2026-11-10 |
| F3 | 启动瞬间在 api 容器内直连 `db:5432` 得到 `ERR ECONNREFUSED`，同一时刻 `docker compose ps` 显示 db 为 `healthy`、api 为 `running` | 会话命令 `docker compose exec api node -e "require('net').connect(5432,'db').on('error',e=>console.log('ERR',e.code)).on('connect',()=>console.log('OK'))"` 输出 `ERR ECONNREFUSED` | `docker compose exec api node -e "require('net').connect(5432,'db').on('error',e=>console.log('ERR',e.code)).on('connect',()=>console.log('OK'))"` | 两服务在同一 compose 网络，Node 18+ | 2026-11-10 |
| F4 | 容器内 DNS 与连接串都正确：`db` 解析为 `172.20.0.2`，`DATABASE_URL` 为 `postgres://postgres:dev@db:5432/app` | `docker compose exec api printenv DATABASE_URL` 输出该串；`node -e "require('dns').lookup('db',...)"` 输出 `null '172.20.0.2'` | `docker compose exec api printenv DATABASE_URL` | compose 默认 bridge 网络，Docker 27.3.1 | 2026-11-10 |
| F5 | `docker compose logs db` 中 `database system is ready to accept connections` 出现两次（初始化期一次、正式启动一次） | 会话观察：`docker compose logs db` 两条 ready 消息 | `docker compose logs db` | postgres:16.4 官方镜像 | 2026-11-10 |
| F6 | 只加客户端连接重试无法根治：`pg` 的 `connectionTimeoutMillis` + 5 次指数退避后，本地连续 20 次 `up` 仍有 3 次失败 | 会话尝试 1 记录：20 次中 3 次失败 | `for i in $(seq 20); do docker compose down -v; docker compose up -d; sleep 1; curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/healthz; done > /tmp/retry-codes.txt; sort /tmp/retry-codes.txt` | 重试上限 5 次、退避总时长短于 Postgres 初始化时长 | 2026-11-10 |
| F7 | 把 `depends_on` 改成 `condition: service_healthy` 后，30 轮 `down -v` + `up -d` + 1 秒后请求全部返回 200，api 日志中 ECONNREFUSED 计数为 0 | 会话验证输出 `30 200`；`docker compose logs api` 中 grep 计数 `0` | `for i in $(seq 30); do docker compose down -v; docker compose up -d; sleep 1; curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/healthz; done > /tmp/codes.txt; sort /tmp/codes.txt` | db 服务已定义 healthcheck，Docker Compose v2.29.7 | 2026-11-10 |
| F8 | db 服务已自带 healthcheck：`test: ["CMD-SHELL", "pg_isready -U postgres"]`、`interval: 2s`、`timeout: 3s`、`retries: 30`，但裸 `depends_on` 不引用它 | `docker-compose.yml` 节选（会话原文） | `docker compose config` | postgres:16.4 官方镜像自带 `pg_isready` | 2026-11-10 |
| F9 | 复现环境版本：Docker 27.3.1、Docker Compose v2.29.7 | `docker --version` 与 `docker compose version` 输出 | `docker compose version` | Linux 主机，docker compose v2 | 2026-11-10 |

## Model

**机制链**：`docker compose up` 同时启动 db 与 api → 裸 `depends_on` 展开为 `condition: service_started`，只等 db 容器进程存在 → api 立刻建连，此刻 Postgres 仍在初始化（F5：ready 消息出现两次，说明存在初始化期实例与正式启动两个阶段）→ 容器内 connect 到 `db:5432` 落到内核拒绝，Node 抛 F1 的报错（F3 实测）→ 报错里的 `127.0.0.1` 是 socket 的本地端点文案，不是目标地址，把排查方向误导到"连接串写错/DNS 坏了"，而 F4 证明这两项都正常 → 数秒后 Postgres 正式监听，同一请求成功，所以表现为概率性失败。

**分类树**（同一症状：从 compose 里的应用容器连 Postgres 被 refused）：
- A 启动竞态：`depends_on` 条件太松，db 未就绪（概率性失败，等待即好）——本技能覆盖
- B Postgres 只监听回环：自建镜像改了 `postgresql.conf` 的 `listen_addresses`，跨 network namespace 永远连不上（每次必失败）
- C 连接串主机名错：`DATABASE_URL` 指向 localhost 或别的服务
- D 端口不匹配：目标端口无人监听
- E db 容器异常：崩溃、OOM、被驱逐，容器非 healthy 或反复 restarting

**判别标准**：
| 近似案例 | 可观测区分信号 |
|---|---|
| B 只监听回环 | 每次都失败、等多久都不行；db 容器内 `postgres -C listen_addresses` 返回 localhost；healthcheck 仍报 healthy（容器内自连成功，所以 `condition: service_healthy` 骗人、无效） |
| C 连接串主机名错 | `docker compose exec api printenv DATABASE_URL` 的主机名不是 `db`；报错目标与 DNS 解析出的 db 地址不一致 |
| D 端口不匹配 | 报错端口不是 5432，或 db 容器内 `pg_isready -p <port>` 失败而 5432 成功 |
| E db 容器异常 | `docker compose ps` 中 db 不是 healthy 或状态为 restarting；`docker compose logs db` 无第二次 ready 消息 |
| A 启动竞态（本技能） | 失败是概率性的；等待 5~10 秒后同一请求成功；db 日志有两条 ready 消息（F5）；加 `condition: service_healthy` 后 30 轮全绿（F7） |

**边界**：只适用于 docker compose v2 且 db 服务已定义可用 healthcheck 的场景。不适用于：Docker Swarm（无 `depends_on` 条件语义）、Kubernetes（等价做法是 readinessProbe + initContainer，本会话未验证）、B 类长期不监听的配置问题（加条件也无效）、以及 db 侧根本没有 healthcheck 且镜像内无 `pg_isready` 的情形。

## Procedure

**前置条件**：能修改 compose 文件；db 服务已定义 healthcheck（F8）；本地可反复 `docker compose down -v` 重建（会清空数据卷，勿在有数据的实例上执行）；当前改动已提交或已备份 `docker-compose.yml`。

**决策表**：
| 入口观测 | 分支 |
|---|---|
| 失败概率性出现，等待 5~10 秒后同一请求成功 | B1 收紧 `depends_on` 条件 |
| 每次必失败、等待无效，且 healthcheck 仍 healthy | B2 查 `listen_addresses`（本技能不适用，见 Model 判别标准） |
| `printenv DATABASE_URL` 的主机名不是 `db` | B3 修连接串（本技能不适用） |
| `docker compose ps` 中 db 非 healthy 或 restarting | B4 查 db 日志与 OOM（本技能不适用） |

**B1 收紧 `depends_on` 条件**
1. `docker compose config`
   - 期望：看到 `depends_on` 下 `db: condition: service_started`
   - 不匹配：已经是 `service_healthy` 却仍报同样错误 → 停止条件 S1
2. `docker compose exec api printenv DATABASE_URL`
   - 期望：`postgres://postgres:dev@db:5432/app`
   - 不匹配：主机名不是 `db` → 转分支 B3
3. `docker compose exec api node -e "require('net').connect(5432,'db').on('error',e=>console.log('ERR',e.code)).on('connect',()=>console.log('OK'))"`
   - 期望：刚 `up` 时输出 `ERR ECONNREFUSED`，十几秒后重跑输出 `OK`
   - 不匹配：始终 `ERR` → 转分支 B2（不是竞态）
4. 编辑 compose：`api.depends_on` 改为映射写法 `db: {condition: service_healthy}`
   - 期望：`docker compose config` 显示 `condition: service_healthy`
   - 不匹配：compose 报配置错误 → 检查缩进与 `depends_on` 层级
5. `for i in $(seq 30); do docker compose down -v; docker compose up -d; sleep 1; curl -s -o /dev/null -w "%{http_code}\n" localhost:3000/healthz; done > /tmp/codes.txt; sort /tmp/codes.txt`
   - 期望：30 行全部 `200`
   - 不匹配：仍有非 200 → 停止条件 S2
6. `docker compose logs api`
   - 期望：不再出现 `ECONNREFUSED`
   - 不匹配：仍出现 → 停止条件 S2

**回滚**：改动只落在 `docker-compose.yml`。放弃本方案时 `git checkout -- docker-compose.yml` 回到改动前，或手工改回 `depends_on: - db` 后 `docker compose up -d` 重建；未改数据卷与镜像，无需其他恢复动作。

**停止条件**：
- S1：`docker compose config` 已是 `condition: service_healthy` 且仍报同样错误 → 根因不是启动竞态，转 B2/B4 重新定位。
- S2：收紧条件后 30 轮仍有失败 → 根因在 db 侧或网络侧，停止本路径，升级为人工排查（收集 `docker compose ps`、`docker compose logs db`、`docker compose logs api`）。
- S3：db 服务没有 healthcheck 或镜像内无 `pg_isready` → 本技能不适用，先补 healthcheck 或改用显式等待脚本，30 分钟内无法补齐则换方案。

## Calibration

**逐条置信度**：
| 事实/结论 | 置信度 | 依据 |
|---|---|---|
| F1 报错串与栈帧 | verified | 会话日志原文 |
| F2 裸 `depends_on` 等价 `service_started` | verified | `docker compose config` 输出 |
| F3 启动瞬间容器内直连 db 被 refused | verified | 容器内 node 命令输出 `ERR ECONNREFUSED` |
| F4 DNS 与 `DATABASE_URL` 正常 | verified | 两条 exec 命令输出 |
| F5 ready 消息出现两次 | verified | `docker compose logs db` 观察 |
| F6 客户端重试只缓解不根治 | verified | 20 次中 3 次失败的实测计数 |
| F7 `condition: service_healthy` 修复有效 | verified | 30 轮全 200 + 日志计数 0 |
| F8 healthcheck 定义存在但未被引用 | verified | compose 文件内容 + `docker compose config` |
| F9 环境版本 | verified | `docker --version`、`docker compose version` |
| "报错里的 `127.0.0.1` 是 socket 本地端点而非目标地址" | inferred | 读 `pg` 源码 `packages/pg/lib/connection.js` 的 errno 文案路径得出，会话未实测 errno 文案与远端地址的对应关系 |
| "初始化期临时实例只监听回环，所以 ready 消息出现两次" | inferred | 只观察到两条 ready 消息，未验证临时实例的 `listen_addresses` |
| "对照机器的根因是 `listen_addresses = 'localhost'`" | inferred | 诊断发生在另一台机器，本会话未复现该配置 |
| "`restart: unless-stopped` 也能掩盖该竞态" | assumed | 未测试 |

**证伪条件**（出现即本技能失效或需重写）：
- Compose 改变裸 `depends_on` 的默认条件，不再等价 `condition: service_started` → F2 失效，机制链需重写。
- postgres 官方镜像取消初始化期临时实例，`docker compose logs db` 只出现一条 ready 消息 → F5 与机制链需重写。
- `pg` 改用远端地址打印连接错误（报错变成 `db:5432`）→ "报错地址是 127.0.0.1" 这条判别信号失效。
- healthcheck 改为从容器外探测 → B 类案例不再"healthcheck 骗人"，判别标准表需更新。

**未知清单**：
- 未验证 Kubernetes 等价做法（readinessProbe + initContainer）；验证方法：在 k8s 部署同一镜像，用 initContainer 轮询 `pg_isready` 后再启动应用。
- 未验证 `restart: unless-stopped` 是否掩盖该竞态；验证方法：加上该字段后重跑 30 轮统计失败次数。
- 未验证把 healthcheck `retries` 从 30 调小对启动时长的影响；验证方法：设 `retries: 5` 后记录 `up` 到首个 200 的耗时。
- 未实测 errno 文案与远端地址的对应关系；验证方法：在容器内连接一个确定被拒绝的远端地址，抓 `strace` 并与 `socket.localAddress` 对照。
- 未在 Docker Desktop（Windows/macOS）验证。

**复审日期**：2027-05-10（到期重跑 Facts 的复核命令，重点 F2、F5、F7）

**使用台账**：
| 日期 | 场景 | 结果 |
|---|---|---|
| 2026-11-10 | 首次抽取（compose + Postgres 启动竞态 ECONNREFUSED） | — |

## See also

- Compose Specification 中 `depends_on` 的 `condition` 取值说明（docs.docker.com）
- postgres 官方镜像初始化流程与 `pg_isready` healthcheck 用法（hub.docker.com/_/postgres）
