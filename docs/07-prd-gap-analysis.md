# PRD Gap Analysis

## Purpose

This document maps the original PRD to the current audit database design direction and highlights open design decisions that still need resolution before implementation.

## Scope of This Repository

This repository is not the full product architecture for the database management platform.

Its current scope is narrower:
- define how PostgreSQL should be used for audit workloads
- define how audit data relates to the broader microservices platform
- provide a reference model for audit, reporting, and control-plane concerns

Because of that, many product-level requirements from the PRD are only partially covered here.

## What Is Already Covered Well

### 1. Audit logging as a first-class concern
The PRD requires transparent and detailed logging for:
- UI access
- API access
- scheduler access
- approval flow
- query failures
- user and tenant attribution

Current design coverage:
- canonical `audit.event_log`
- row-level `audit.entity_change_log`
- access-oriented `audit.access_log`
- actor, entity, request, and correlation tracking
- guidance for append-only audit storage

Status: Covered at a strong conceptual level.

### 2. Multi-service architecture alignment
The PRD clearly separates:
- API Gateway
- Auth
- Billing/License Gateway
- Notification
- Scheduler
- Edge Query Worker

Current design coverage:
- audit PostgreSQL positioned outside operational service databases
- event-driven integration via outbox / worker / async ingestion
- audit capture from multiple service boundaries

Status: Covered conceptually.

### 3. Multi-tenant awareness
The PRD requires tenant binding for cloud mode and optional/default tenant behavior for self-hosted mode.

Current design coverage:
- `tenant_id` included as a first-class audit dimension
- recommendations for tenant-aware indexing
- recommendations for avoiding cross-tenant ambiguity in audit records

Status: Covered conceptually.

### 4. Approval and risk workflow observability
The PRD requires hybrid approval with pending, approved, rejected states and secure review flow.

Current design coverage:
- approval events represented in canonical audit model
- request ID and correlation ID strategy supports tracing approval-to-execution lifecycle
- sample README architecture includes approval event insertion into audit DB

Status: Covered at event-flow level, but not yet modeled in full relational detail.

### 5. Guardrails, retention, and operational safety
The PRD emphasizes timeout, row limit, and operational stability.

Current design coverage:
- audit storage separated from heavy operational query execution
- partitioning and retention strategy defined
- archive strategy defined for long-term storage

Status: Covered for audit platform operations, not yet tied to product runtime enforcement data structures.

## What Is Only Partially Covered

### 1. Product internal schema versus audit schema
The PRD includes a broad internal schema for:
- tenants
n- users
- db_connections
- user_db_permissions
- query_whitelists
- api_keys
- scheduled_jobs
- audit_logs
- query_approvals
- system_settings
- webhooks
- license_configs
- subscriptions
- usage_metrics

Current repo focus:
- mostly audit-side schema and architecture
- not yet a complete internal application schema design

Gap:
- the relationship between application operational tables and audit tables is not yet normalized into a full data ownership matrix

Status: Partial.

### 2. Billing and license event modeling
The PRD makes billing and licensing central to the business model.

Current design coverage:
- billing/license gateway appears in architecture
- license checks and safe-lock are represented at flow level

Gap:
- no dedicated audit event taxonomy yet for:
  - license validation
  - heartbeat success/failure
  - plan upgrades/downgrades
  - quota exhaustion
  - safe-lock activation/deactivation

Status: Partial.

### 3. Notification and webhook auditability
The PRD requires dynamic webhooks and secret-backed signed payloads.

Current design coverage:
- notifications shown in architecture flow
- access/event logging concept exists

Gap:
- no explicit design yet for webhook delivery audit, retry audit, secret rotation audit, or signature verification failure events

Status: Partial.

### 4. Scheduled job observability depth
The PRD requires scheduled query execution and failure notification.

Current design coverage:
- scheduler flow appears in README diagram
- scheduler writes audit events conceptually

Gap:
- no explicit event naming convention yet for job lifecycle:
  - job.created
  - job.updated
  - job.triggered
  - job.started
  - job.completed
  - job.failed
  - job.disabled

Status: Partial.

### 5. Export and sensitive data access logging
The PRD requires export to CSV/JSON/Excel and secure operations.

Current design coverage:
- `audit.access_log` can track export activity

Gap:
- no explicit export model yet for:
  - export file generation
  - download completion
  - export size
  - destination / channel
  - whether export included masked or raw data

Status: Partial.

## What Is Not Covered Yet

### 1. Concrete DDL
There is no actual SQL DDL yet for:
- schemas
- partitioned tables
- indexes
- privileges
- retention jobs

Impact:
- current repository is still architectural, not implementation-ready

Status: Not covered.

### 2. Event taxonomy catalog
The design references event types, but there is no authoritative event catalog per domain.

Examples still needed:
- auth.*
- query.*
- approval.*
- billing.*
- license.*
- scheduler.*
- webhook.*
- connection.*
- export.*

Impact:
- cross-service consistency will drift without a canonical event catalog

Status: Not covered.

### 3. Query execution result model
The PRD strongly centers on query execution, but the current design does not yet define whether audit should store:
- raw query text only
- normalized query text
- query fingerprint
- explain plan summary
- rows returned
- rows affected
- execution duration
- result truncation reason
- timeout flag
- SSH tunnel metadata

Impact:
- investigation usefulness may be limited if execution metadata is underspecified

Status: Not covered.

### 4. Data classification and masking policy
The PRD touches security and enterprise usage, but there is no explicit audit-side policy for:
- masking secrets in query text
- redacting credentials and tokens
- handling PII in payloads
- storing hashed versus raw identifiers

Impact:
- audit logging can become a security liability if sensitive values are stored blindly

Status: Not covered.

### 5. Core portability strategy for non-Postgres internal DBs
The PRD says the application core can run on PostgreSQL, MySQL, or SQLite.

Current repo direction:
- focused on PostgreSQL for audit storage

Gap:
- no decision note yet on whether:
  - audit always requires PostgreSQL, even if product core runs on MySQL/SQLite
  - or audit abstraction must support multiple engines too

Impact:
- deployment guidance is incomplete for self-hosted lightweight installations

Status: Not covered.

### 6. Operational ownership model
The PRD is microservices-native, but current docs do not explicitly assign ownership for audit writes.

Open questions:
- does Gateway write audit directly?
- does Worker write execution detail directly?
- is there a dedicated Audit Ingestion Service?
- who owns retries and deduplication?

Status: Not covered.

## Key Design Decisions Still Needed

### Decision 1: Is PostgreSQL mandatory for audit?
Recommended answer:
- yes for serious production deployments
- optional simplification only for demos or very small installs

Reason:
- partitioning, indexing, JSONB, and investigation queries fit PostgreSQL best

### Decision 2: What is the canonical writer path?
Recommended answer:
- services write local outbox records
- dedicated ingestion path publishes canonical audit events into PostgreSQL

Reason:
- avoids inconsistent direct writes from many services
- improves idempotency and replayability

### Decision 3: How much query text should be stored?
Recommended answer:
- store normalized query text and fingerprint by default
- allow encrypted raw text only when policy allows it

Reason:
- reduces sensitive-data leakage in audit storage
- still supports investigations and analytics

### Decision 4: Should execution result metadata be first-class?
Recommended answer:
- yes
- execution duration, row count, rows affected, timeout status, dry-run flag, approval status, and error class should be explicit columns or structured metadata

### Decision 5: Is reporting inside the same cluster initially?
Recommended answer:
- yes initially via separate schema
- split later when report workloads begin to affect audit write or investigation performance

## Recommended Next Documents

To close the most important gaps, the next docs should be created in this order:

1. `docs/08-event-taxonomy.md`
   - define canonical event names and required fields per domain
2. `docs/09-execution-metadata-model.md`
   - define what execution-level data must be captured for each query attempt
3. `docs/10-ddl-draft.md` or `sql/001_init_audit_schema.sql`
   - define implementation-ready PostgreSQL schema
4. `docs/11-security-and-redaction-policy.md`
   - define masking, retention, and sensitive-field handling
5. `docs/12-service-ownership.md`
   - define which service emits which audit events and through what path

## Summary

The current repository already provides a strong architectural direction for PostgreSQL as an audit platform inside the broader database-management product described in the PRD.

However, it is still one layer below a full product design and one layer above implementation.

The biggest remaining gaps are:
- canonical event taxonomy
- concrete DDL
- execution metadata detail
- sensitive-data masking policy
- service ownership for audit ingestion

Closing those gaps will turn the repository from architecture notes into an implementation-ready audit design package.
