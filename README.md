# audit-db

PostgreSQL audit database design notes and reference architecture.

This repository documents a best-case audit database design when the main operational databases remain separated by service/domain, while PostgreSQL is used for audit, reporting, and control-plane workloads.

## Docs

- `docs/01-overview.md` — architecture summary and positioning of PostgreSQL
- `docs/02-architecture.md` — logical system architecture and data flow
- `docs/03-audit-data-model.md` — canonical audit schema and table design
- `docs/04-postgres-physical-design.md` — partitioning, indexing, retention, and security
- `docs/05-rollout-plan.md` — phased implementation and rollout plan
- `docs/06-sample-queries.md` — sample investigation and reporting queries
