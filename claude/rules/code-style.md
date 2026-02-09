# Code Style Rules

Rules beyond pre-commit (ruff format/lint).

## Design Patterns

- **Prefer composition over inheritance**: Avoid deep class hierarchies
  - Good: `Component` holds a `Dependency` instance
  - Avoid: `ExtendedComponent(Component)` → `SpecializedExtendedComponent(ExtendedComponent)`
- Keep inheritance shallow (≤2 levels when possible)
- Use mixins sparingly; prefer explicit delegation

## Logging

- Use descriptive logger names with PascalCase, NOT `print` or ambiguous names
  - Good: `getLogger("DataPipeline")`, `getLogger("APIService")`, `getLogger("AuthMiddleware")`
  - Avoid: `getLogger(__name__)` or overly generic names
- For distributed systems: `[{Component} Rank {N}]` (e.g., `[DataProcessor Rank 0]`)
- Log levels:
  - DEBUG: Detailed tracing (avoid in hot paths)
  - INFO: Milestones (process start, operation completed)
  - WARNING: Recoverable issues
  - ERROR: Failures requiring attention
- Configure logger colors and formats consistently across the project

## Performance Patterns

- **Avoid GPU-CPU sync**: `.item()`, `.tolist()`, `print(tensor)` cause sync
- **Prefer batch operations**: Avoid Python loops over tensor elements
- **In-place ops**: Use when safe, but careful with autograd (`.add_()` vs `+`)

## Naming Conventions

| Type             | Pattern       | Example                             |
| ---------------- | ------------- | ----------------------------------- |
| Config dataclass | `XxxConfig`   | `DatabaseConfig`, `APIConfig`       |
| Service class    | `XxxService`  | `AuthService`, `DataService`        |
| Manager class    | `XxxManager`  | `ConnectionManager`, `CacheManager` |
| Handler class    | `XxxHandler`  | `RequestHandler`, `EventHandler`    |
| Utility function | `xxx_util`    | `file_util`, `string_util`          |

## Tensor Conventions

- Shape convention: `[batch, seq_len, hidden]` or document clearly
- Use `torch.Size` assertions for shape validation in debug
- Prefer explicit dtype/device over implicit conversion

## Import Style

- Group imports: stdlib, third-party, local/project (ruff handles order)
- Avoid `from x import *` (except in __init__.py for clean APIs)
- Prefer explicit imports over module-level imports for large modules
