# Event Taxonomy

## Purpose

This document defines the canonical audit event taxonomy for the database management platform described in the PRD.

Goals:
- keep event naming consistent across services
- make audit queries predictable
- support investigations, compliance review, and operational analytics
- reduce drift between UI, API, scheduler, approval, billing, and worker components

## Naming Convention

Canonical event name format:

`domain.entity.action`

Examples:
- `auth.user.login_succeeded`
- `query.execution.started`
- `approval.request.approved`
- `license.heartbeat.failed`
- `scheduler.job.failed`

## Event Envelope

Every canonical audit event should include at least these common fields:
- `event_id`
- `occurred_at`
- `service_name`
- `environment`
- `tenant_id`
- `event_type`
- `entity_type`
- `entity_id`
- `actor_type`
- `actor_id`
- `request_id`
- `correlation_id`
- `status`
- `metadata`
- `payload`

Optional but strongly recommended:
- `session_id`
- `access_source`
- `connection_id`
- `approval_id`
- `job_id`
- `api_key_id`
- `client_ip`
- `user_agent`

## Common Status Values

Preferred status vocabulary:
- `success`
- `failed`
- `denied`
- `pending`
- `approved`
- `rejected`
- `started`
- `completed`
- `timed_out`
- `truncated`
- `skipped`

## Domain Catalog

### 1. Auth Domain

Use for login, logout, token/session activity, and identity-provider events.

Recommended events:
- `auth.user.login_succeeded`
- `auth.user.login_failed`
- `auth.user.logout_succeeded`
- `auth.session.created`
- `auth.session.revoked`
- `auth.api_key.created`
- `auth.api_key.revoked`
- `auth.api_key.used`
- `auth.sso.callback_failed`

Required payload hints:
- auth provider
- failure reason if any
- authentication method
- API key name or ID reference if relevant

### 2. Connection Domain

Use for target database connection management.

Recommended events:
- `connection.target.created`
- `connection.target.updated`
- `connection.target.deleted`
- `connection.target.test_succeeded`
- `connection.target.test_failed`
- `connection.target.role_provisioned`
- `connection.target.role_provision_failed`
- `connection.ssh_tunnel.configured`
- `connection.ssh_tunnel.validation_failed`

Required payload hints:
- target DB type
- connection identifier
- SSH enabled flag
- provisioning mode

### 3. Query Domain

Use for query lifecycle from request to execution result.

Recommended events:
- `query.request.received`
- `query.request.validated`
- `query.request.denied`
- `query.risk.assessed`
- `query.dry_run.started`
- `query.dry_run.completed`
- `query.dry_run.failed`
- `query.execution.started`
- `query.execution.completed`
- `query.execution.failed`
- `query.execution.timed_out`
- `query.execution.truncated`
- `query.execution.cancelled`

Required payload hints:
- mode (`dry_run` or `execute`)
- query fingerprint
- normalized query
- connection ID
- timeout and row limit in effect
- execution duration if available
- rows returned / rows affected if available

### 4. Approval Domain

Use for approval lifecycle and reviewer actions.

Recommended events:
- `approval.request.created`
- `approval.request.notified`
- `approval.request.viewed`
- `approval.request.approved`
- `approval.request.rejected`
- `approval.request.expired`
- `approval.request.cancelled`

Required payload hints:
- approval ID
- risk classification
- reviewer identity if decision occurred
- decision reason
- linked execution request ID

### 5. Scheduler Domain

Use for scheduled jobs and recurring query execution.

Recommended events:
- `scheduler.job.created`
- `scheduler.job.updated`
- `scheduler.job.paused`
- `scheduler.job.resumed`
- `scheduler.job.disabled`
- `scheduler.job.triggered`
- `scheduler.job.started`
- `scheduler.job.completed`
- `scheduler.job.failed`
- `scheduler.job.missed`

Required payload hints:
- job ID
- cron expression
- trigger source
- linked query execution request ID
- failure class if any

### 6. Export Domain

Use for data export and download tracking.

Recommended events:
- `export.request.created`
- `export.file.generated`
- `export.file.downloaded`
- `export.file.expired`
- `export.file.deleted`
- `export.request.failed`

Required payload hints:
- export ID
- format (`csv`, `json`, `xlsx`)
- record count
- file size
- masking mode
- requester identity

### 7. Webhook Domain

Use for outbound notification and webhook lifecycle.

Recommended events:
- `webhook.endpoint.created`
- `webhook.endpoint.updated`
- `webhook.endpoint.deleted`
- `webhook.delivery.started`
- `webhook.delivery.succeeded`
- `webhook.delivery.failed`
- `webhook.delivery.retried`
- `webhook.secret.rotated`
- `webhook.signature.validation_failed`

Required payload hints:
- webhook ID
- trigger event
- delivery attempt number
- response code
- latency

### 8. Billing Domain

Use for plan and quota events in cloud mode.

Recommended events:
- `billing.subscription.created`
- `billing.subscription.updated`
- `billing.subscription.canceled`
- `billing.plan.upgraded`
- `billing.plan.downgraded`
- `billing.quota.warning`
- `billing.quota.exceeded`
- `billing.invoice.paid`
- `billing.invoice.payment_failed`

Required payload hints:
- subscription ID
- plan ID
- payment provider
- billing period
- quota metric name and value

### 9. License Domain

Use for self-hosted license validation and safe-lock handling.

Recommended events:
- `license.key.activated`
- `license.validation.succeeded`
- `license.validation.failed`
- `license.heartbeat.started`
- `license.heartbeat.succeeded`
- `license.heartbeat.failed`
- `license.status.expiring_soon`
- `license.status.expired`
- `license.safe_lock.enabled`
- `license.safe_lock.disabled`

Required payload hints:
- license tier
- expiry date
- validation mode (`online`, `offline_signed_token`)
- heartbeat response class
- safe-lock reason

### 10. Settings and Policy Domain

Use for configuration and policy changes.

Recommended events:
- `settings.global.updated`
- `settings.tenant.updated`
- `policy.whitelist.created`
- `policy.whitelist.updated`
- `policy.whitelist.deleted`
- `policy.rbac.updated`
- `policy.guardrail.updated`

Required payload hints:
- changed key names
- before/after summary
- actor identity
- scope (`global`, `tenant`, `connection`)

## Required Field Matrix by Domain

### Query events
Must include:
- `connection_id`
- `access_source`
- `query_fingerprint`
- `mode`
- `status`

### Approval events
Must include:
- `approval_id`
- `request_id`
- `risk_level`
- `status`

### Scheduler events
Must include:
- `job_id`
- `schedule_expression`
- `trigger_source`
- `status`

### Billing events
Must include:
- `subscription_id`
- `plan_id`
- `status`

### License events
Must include:
- `license_tier`
- `license_status`
- `validation_mode`
- `status`

## Event Design Rules

1. Use past tense only for facts that already happened.
   - good: `query.execution.completed`
   - avoid using vague event names like `query.process`

2. Keep action semantics specific.
   - prefer `approved`, `rejected`, `timed_out`, `retried`
   - avoid ambiguous names like `updated_status`

3. Keep domain ownership obvious.
   - auth emits auth events
   - scheduler emits scheduler lifecycle events
   - worker emits execution events
   - billing/license services emit commercial compliance events

4. Do not overload one event type for many states.
   - prefer `approval.request.approved` and `approval.request.rejected`
   - do not rely only on one generic `approval.request.updated`

5. Keep searchable fields first-class.
   - event type, status, actor, entity, request ID, correlation ID, connection ID
   - do not bury critical filters only inside JSON payloads

## Recommended First Implementation Set

If implementation starts incrementally, prioritize these events first:
- `auth.user.login_succeeded`
- `auth.api_key.used`
- `query.request.received`
- `query.request.denied`
- `query.dry_run.completed`
- `query.execution.completed`
- `query.execution.failed`
- `approval.request.created`
- `approval.request.approved`
- `approval.request.rejected`
- `scheduler.job.completed`
- `scheduler.job.failed`
- `license.heartbeat.failed`
- `license.safe_lock.enabled`
- `billing.quota.exceeded`
- `export.file.downloaded`

## Summary

A stable taxonomy is essential before final DDL and service integration work. Without it, different services will emit inconsistent names and the audit database will lose much of its value for investigation and compliance review.
