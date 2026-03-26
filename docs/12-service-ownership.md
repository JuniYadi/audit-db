# Service Ownership

## Purpose

This document defines which service is responsible for producing which audit events, how those events flow into PostgreSQL, and where retries and deduplication should live.

Without explicit ownership, audit systems tend to fail in two ways:
- duplicate writes from multiple services
- missing writes because every service assumes another service will handle them

## Recommended Ownership Model

Use a layered ownership approach:

1. Each service owns facts that only it can reliably observe.
2. Each service writes those facts into its own local operational store or outbox.
3. A dedicated audit ingestion path converts them into canonical audit events in PostgreSQL.
4. The audit database should be the canonical read model for investigation, not the first place every service writes bespoke payloads.

## Preferred Write Path

Recommended pattern:
- service handles business action
- service writes local outbox event in same transaction as its own state change
- publisher or ingestion component reads outbox
- ingestion component writes canonical event to PostgreSQL audit DB
- ingestion path handles deduplication and retry

This is preferred over letting every service write directly to audit PostgreSQL.

## Service-by-Service Ownership

### 1. API Gateway Service

Owns facts about:
- inbound request receipt
- access source classification
- request ID and correlation ID assignment
- initial auth context attachment
- initial policy denial before worker handoff

Recommended events:
- `query.request.received`
- `query.request.denied`
- `query.risk.assessed`
- `export.request.created`

Must not be sole owner of:
- actual execution success/failure inside target DB
- SSH tunnel behavior inside worker

### 2. Auth Service

Owns facts about:
- login and logout
- session creation and revocation
- SSO callback outcomes
- API key issuance and revocation

Recommended events:
- `auth.user.login_succeeded`
- `auth.user.login_failed`
- `auth.session.created`
- `auth.session.revoked`
- `auth.api_key.created`
- `auth.api_key.revoked`
- `auth.api_key.used`

### 3. Billing/License Gateway

Owns facts about:
- license validation result
- subscription state transitions
- quota exhaustion and safe-lock logic
- heartbeat status for self-hosted instances

Recommended events:
- `billing.subscription.updated`
- `billing.quota.warning`
- `billing.quota.exceeded`
- `license.validation.succeeded`
- `license.validation.failed`
- `license.heartbeat.succeeded`
- `license.heartbeat.failed`
- `license.safe_lock.enabled`
- `license.safe_lock.disabled`

### 4. Approval Service or Approval Module

If approval logic is a separate service, it owns approval workflow facts. If approval remains inside Gateway initially, the module still owns the event semantics.

Owns facts about:
- approval request creation
- reviewer decisions
- expiration or cancellation of approval requests

Recommended events:
- `approval.request.created`
- `approval.request.notified`
- `approval.request.approved`
- `approval.request.rejected`
- `approval.request.expired`
- `approval.request.cancelled`

### 5. Edge Query Worker

Owns facts about:
- SSH tunnel setup and failure
- actual execution start and finish
- timeout, truncation, and DB-originated failure
- target database metadata seen at runtime

Recommended events:
- `query.dry_run.started`
- `query.dry_run.completed`
- `query.dry_run.failed`
- `query.execution.started`
- `query.execution.completed`
- `query.execution.failed`
- `query.execution.timed_out`
- `query.execution.truncated`
- `connection.target.test_failed`

The worker should also own execution-level metadata emitted into the execution log model.

### 6. Scheduler Service

Owns facts about:
- job lifecycle
- trigger time
- missed jobs
- scheduler-owned retries

Recommended events:
- `scheduler.job.created`
- `scheduler.job.updated`
- `scheduler.job.paused`
- `scheduler.job.resumed`
- `scheduler.job.triggered`
- `scheduler.job.completed`
- `scheduler.job.failed`
- `scheduler.job.missed`

The scheduler should not pretend to own target DB execution facts; it should link to worker-produced execution events.

### 7. Notification Service

Owns facts about:
- outbound webhook or email delivery attempts
- delivery response status
- retry sequence
- secret rotation if managed there

Recommended events:
- `webhook.delivery.started`
- `webhook.delivery.succeeded`
- `webhook.delivery.failed`
- `webhook.delivery.retried`
- `webhook.secret.rotated`

### 8. Admin Settings / Policy Service

Owns facts about:
- global settings changes
- tenant settings changes
- whitelist updates
- policy rule changes

Recommended events:
- `settings.global.updated`
- `settings.tenant.updated`
- `policy.whitelist.created`
- `policy.whitelist.updated`
- `policy.whitelist.deleted`
- `policy.guardrail.updated`
- `policy.rbac.updated`

## Audit Ingestion Ownership

A dedicated ingestion path should own:
- canonical event validation
- schema normalization
- deduplication
- replay support
- dead-letter handling
- PostgreSQL write strategy

This can be implemented as:
- a dedicated Audit Ingestion Service
- or a shared ingestion worker process used by multiple services

Recommended responsibilities:
- validate event envelope
- enrich with environment and ingestion timestamp
- reject malformed events
- detect duplicates by `event_id`
- write to partitioned audit tables
- route failed writes to dead-letter handling

## Deduplication Strategy

Deduplication should not be pushed to every producer service.

Recommended approach:
- each producer emits stable `event_id`
- audit ingestion enforces uniqueness on `event_id`
- replay is safe because duplicate inserts become no-op or conflict-ignore operations

## Retry Ownership

Recommended split:
- producer service retries only local outbox publication
- audit ingestion retries PostgreSQL insertion
- notification retries remain owned by Notification Service
- scheduler retries remain owned by Scheduler Service
- worker retries for execution should be explicit and not hidden inside audit logging

## Direct Write Exceptions

Direct write to audit PostgreSQL may be acceptable for:
- a very small monolith deployment
- development mode
- early prototype phase

Even then, keep the event contract identical to the future ingestion contract so migration is easier later.

## Suggested Reference Flow

### Query execution flow
1. Gateway receives request and writes outbox event `query.request.received`.
2. Gateway validates policy and writes `query.risk.assessed` or `query.request.denied`.
3. If approval needed, approval module writes approval events.
4. Worker executes query and writes execution events plus execution metadata.
5. Ingestion path normalizes all events into PostgreSQL audit tables.

### Scheduled job flow
1. Scheduler triggers job and emits `scheduler.job.triggered`.
2. Worker executes linked query and emits execution events.
3. Scheduler emits `scheduler.job.completed` or `scheduler.job.failed`.
4. Notification service emits webhook delivery events if alerts are sent.
5. Ingestion path stores all linked events using request/correlation IDs.

## Ownership Anti-Patterns to Avoid

- Gateway writes final execution success even though Worker owns the result.
- Worker writes login events even though Auth owns them.
- Scheduler writes webhook delivery outcomes even though Notification owns them.
- every service writes directly to audit DB with different payload shapes.
- no service owns correlation IDs consistently.

## Summary

The safest ownership rule is simple:
- producers own raw facts
- ingestion owns canonicalization
- PostgreSQL audit DB owns the investigative read model

That separation keeps audit records accurate, replayable, and consistent across the platform.
