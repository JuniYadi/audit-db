# PostgreSQL Physical Design

## Partitioning

Audit tables should be partitioned by time from the start.

Recommended strategy:
- RANGE partitioning on `occurred_at` for `audit.event_log`
- RANGE partitioning on `changed_at` for `audit.entity_change_log`
- monthly partitions

Examples:
- `audit.event_log_2026_03`
- `audit.event_log_2026_04`

Benefits:
- easier retention management
- better range query performance
- healthier vacuum behavior
- simpler archive and drop workflow

## Indexing Strategy

Do not over-index append-only audit tables.

### `audit.event_log`
Recommended indexes:
- `(occurred_at desc)`
- `(tenant_id, occurred_at desc)`
- `(entity_type, entity_id, occurred_at desc)`
- `(actor_id, occurred_at desc)`
- `(event_type, occurred_at desc)`
- `(request_id)`
- `(correlation_id)`

### `audit.entity_change_log`
Recommended indexes:
- `(changed_at desc)`
- `(table_name, record_pk, changed_at desc)`
- `(changed_by, changed_at desc)`

### JSONB Indexing
Use GIN only for frequently queried keys. Avoid broad GIN indexing on every JSONB payload because it increases write cost.

## Retention and Archive

Example policy:
- 90 days in hot PostgreSQL partitions
- 12 months in warm storage or lower-cost partitions
- older than 12 months archived to object storage

Archive formats:
- parquet
- CSV
- compressed JSON

## Security Model

Recommended roles:
- `audit_writer`
- `audit_reader`
- `audit_admin`
- `audit_archiver`

Rules:
- `audit_writer` can insert only
- `audit_writer` cannot update or delete audit rows
- `audit_reader` is read-only
- only controlled maintenance roles can archive or drop old partitions

## Tamper Resistance

Minimum controls:
- append-only permission model
- server-generated timestamps
- periodic checksum or hash export
- archive batches signed or hashed before offloading to object storage

If stronger controls are required, add event hash chaining or signed export manifests.

## Multi-Tenant Notes

If the platform is multi-tenant:
- include `tenant_id` in all audit records unless the event is truly global
- index by `tenant_id` and time
- avoid premature RLS unless tenants query the database directly

## Anti-Patterns to Avoid

- one giant unpartitioned audit table
- storing everything as opaque text blobs
- missing `request_id` and `correlation_id`
- trigger-based audit on every table without prioritization
- allowing application users to modify audit history
- using audit PostgreSQL as a replacement for observability logs
