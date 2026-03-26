# PostgreSQL Audit DB Overview

## Goal

Design a PostgreSQL-based audit database for a system where the main operational databases are already separated by service or domain.

## Core Positioning

PostgreSQL should not become the single database for every workload.

Best-case positioning:
- operational databases stay separated by service/domain
- PostgreSQL is introduced as an audit database
- PostgreSQL may also support reporting and control-plane workloads
- cross-service integration happens through events, outbox, or CDC, not direct joins across operational databases

## Why PostgreSQL Still Fits

PostgreSQL is a strong fit when the audit platform needs:
- relational integrity
- reliable transactional writes
- flexible querying for investigations
- JSONB for semi-structured event payloads
- indexing by actor, entity, and time
- partitioning for large append-only datasets
- easy support for reporting, exports, and BI tools

## When PostgreSQL Is Not the Primary Choice

PostgreSQL is less ideal when the audit stream behaves more like observability telemetry:
- extremely high write volume with mostly write-only access
- very long retention in hot storage
- large-scale log analytics replacing ELK or ClickHouse

In those cases, PostgreSQL can still hold the authoritative audit record for business actions, while cold archives or log analytics platforms handle bulk historical analysis.

## Design Principles

1. Separate operational and audit concerns.
2. Keep audit data append-only.
3. Standardize audit events across services.
4. Capture both business-level events and critical row-level changes.
5. Partition by time from the beginning.
6. Retain hot data in PostgreSQL, archive older data to object storage.
7. Prevent application roles from updating or deleting audit history.
