# Execution Metadata Model

## Purpose

This document defines the execution-attempt metadata that should be captured for every query-related operation.

It complements the canonical event taxonomy by specifying what must be recorded when a user, API client, or scheduler submits a dry run or live execution request.

## Why This Matters

A basic audit log containing only query text and timestamp is not enough.

For investigation, support, compliance, and billing, the system should be able to answer:
- who executed the query?
- on which target database and connection?
- through which source path (UI, API, scheduler)?
- was it dry run or real execution?
- how long did it take?
- how many rows were returned or affected?
- was the result truncated?
- did it require approval?
- did it time out?
- did it use SSH tunneling?
- what error class occurred if it failed?

## Modeling Approach

Use two complementary layers:

1. Canonical event rows in `audit.event_log`
   - record lifecycle facts such as request received, execution started, completed, failed

2. One execution-attempt record per execution in a dedicated structure
   - stores stable execution metadata in a consistent shape

Recommended table name:
- `audit.query_execution_log`

## Record Granularity

One record in `audit.query_execution_log` should represent one execution attempt.

Examples:
- one dry run request = one attempt
- one actual execution = one attempt
- a retried scheduled job = multiple attempts
- approval request and final execution are separate facts, but linked through IDs

## Required Identifiers

Every execution attempt should include:
- `execution_id`
- `request_id`
- `correlation_id`
- `tenant_id`
- `user_id` if user-originated
- `api_key_id` if API-key-originated
- `job_id` if scheduler-originated
- `approval_id` if approval was involved
- `connection_id`
- `service_name`
- `worker_id` or worker instance identifier if available

## Required Classification Fields

Recommended fields:
- `access_source` (`ui`, `api`, `scheduler`, `system`)
- `execution_mode` (`dry_run`, `execute`)
- `statement_type` (`select`, `insert`, `update`, `delete`, `ddl`, `unknown`)
- `risk_level` (`low`, `medium`, `high`, `critical`)
- `approval_status` (`not_required`, `pending`, `approved`, `rejected`)
- `final_status` (`success`, `failed`, `timed_out`, `truncated`, `cancelled`, `denied`)

## Query Representation Fields

Store query information in a controlled and policy-aware shape.

Recommended fields:
- `query_text_normalized`
- `query_fingerprint`
- `query_text_encrypted` (optional, policy-driven)
- `query_hash`
- `query_length`
- `parameter_count`
- `contains_write_operation`
- `contains_ddl`
- `contains_sensitive_pattern`

Recommended rule:
- normalized text and fingerprint are default
- encrypted raw text is optional and controlled by policy

## Target Database Fields

Recommended fields:
- `target_db_type`
- `target_db_version` if available
- `target_database_name`
- `target_schema_name` if known
- `target_host_label` or logical connection name
- `ssh_tunnel_used`
- `ssh_profile_id` or tunnel config reference

Do not store raw secrets in audit metadata.

## Runtime Guardrail Fields

Recommended fields:
- `configured_timeout_ms`
- `configured_row_limit`
- `effective_timeout_ms`
- `effective_row_limit`
- `guardrail_source` (`cache`, `db_default`, `tenant_override`, `global_override`)

These fields are important because investigations often need to know which settings were active at execution time.

## Timing Fields

Recommended fields:
- `requested_at`
- `queued_at`
- `started_at`
- `completed_at`
- `duration_ms`
- `queue_delay_ms`

For dry run and direct execution, `queued_at` may be null.

## Result Fields

Recommended fields:
- `rows_returned`
- `rows_affected`
- `result_truncated`
- `truncation_reason`
- `result_size_bytes`
- `plan_summary` for dry run / explain
- `commit_applied` boolean

For dry run:
- `commit_applied` should always be false

For failed requests:
- rows fields may be null

## Error Fields

Recommended fields:
- `error_class`
- `error_code`
- `error_message_sanitized`
- `error_origin` (`gateway`, `worker`, `target_db`, `ssh_tunnel`, `policy`, `approval`)
- `retryable` boolean

Do not store unsanitized secrets, DSNs, or tokens inside error payloads.

## Approval Linkage Fields

Recommended fields:
- `approval_required` boolean
- `approval_id`
- `approval_requested_at`
- `approved_by`
- `approved_at`
- `approval_reason`

These fields allow a single execution attempt to be tied back to the approval workflow.

## Billing and Usage Fields

Recommended fields:
- `billable` boolean
- `usage_metric_incremented` boolean
- `billing_metric_name`
- `billing_units`
- `subscription_plan_id` if available

Not every query must be billed directly, but this should be explicit when usage accounting matters.

## Security and Forensic Fields

Recommended fields:
- `client_ip`
- `user_agent`
- `session_id`
- `mfa_context_present` boolean if applicable
- `policy_version`
- `whitelist_match_id`
- `risk_rule_id`

These are valuable when reconstructing how a request passed validation.

## Suggested Table Shape

High-level example fields for `audit.query_execution_log`:
- `id uuid primary key`
- `occurred_at timestamptz not null`
- `tenant_id text null`
- `request_id text not null`
- `correlation_id text null`
- `execution_mode text not null`
- `access_source text not null`
- `user_id text null`
- `api_key_id text null`
- `job_id text null`
- `approval_id text null`
- `connection_id text not null`
- `target_db_type text not null`
- `ssh_tunnel_used boolean not null default false`
- `query_fingerprint text not null`
- `query_text_normalized text not null`
- `query_hash text null`
- `statement_type text null`
- `risk_level text null`
- `approval_status text null`
- `final_status text not null`
- `configured_timeout_ms integer null`
- `configured_row_limit integer null`
- `started_at timestamptz null`
- `completed_at timestamptz null`
- `duration_ms integer null`
- `rows_returned bigint null`
- `rows_affected bigint null`
- `result_truncated boolean not null default false`
- `truncation_reason text null`
- `result_size_bytes bigint null`
- `error_class text null`
- `error_code text null`
- `error_message_sanitized text null`
- `client_ip inet null`
- `user_agent text null`
- `metadata jsonb not null default '{}'::jsonb`

## Indexing Recommendations

Recommended indexes:
- `(occurred_at desc)`
- `(tenant_id, occurred_at desc)`
- `(connection_id, occurred_at desc)`
- `(query_fingerprint, occurred_at desc)`
- `(user_id, occurred_at desc)`
- `(job_id, occurred_at desc)`
- `(approval_id)`
- `(request_id)`
- `(correlation_id)`
- `(final_status, occurred_at desc)`

## Retention Considerations

Execution logs can grow very quickly. Recommended strategy:
- hot storage for recent attempts in PostgreSQL
- partition by time
- archive older records to object storage if full-fidelity history is required
- keep aggregated reporting data separately if high-volume querying is expected

## Minimum Viable Execution Metadata

If the team wants a smaller initial implementation, capture at least:
- request ID
- tenant ID
- actor identity
- source (`ui`, `api`, `scheduler`)
- mode (`dry_run`, `execute`)
- connection ID
- target DB type
- query fingerprint
- normalized query text
- final status
- duration
- rows returned / affected
- timeout and row limit
- approval ID and approval status
- error class and sanitized message

## Summary

The execution metadata model is the bridge between generic audit events and real query forensics. Without it, the system will know that something happened, but not enough about how or why it happened.
