# Canonical Audit Data Model

## Schema Layout

Recommended schemas:
- `audit`
- `control`
- `report`
- `ref`

## Table 1: `audit.event_log`

Purpose:
- stores business-level audit events across all services

Recommended columns:
- `id uuid primary key`
- `occurred_at timestamptz not null`
- `ingested_at timestamptz not null default now()`
- `tenant_id text null`
- `service_name text not null`
- `environment text not null`
- `event_type text not null`
- `entity_type text null`
- `entity_id text null`
- `actor_type text null`
- `actor_id text null`
- `actor_identifier text null`
- `request_id text null`
- `correlation_id text null`
- `session_id text null`
- `source_ip inet null`
- `user_agent text null`
- `action text null`
- `status text null`
- `reason text null`
- `metadata jsonb not null default '{}'::jsonb`
- `payload jsonb not null default '{}'::jsonb`

Typical examples:
- `auth.user.login_failed`
- `order.order.created`
- `billing.invoice.paid`
- `admin.role.updated`

## Table 2: `audit.entity_change_log`

Purpose:
- stores before/after changes for critical tables

Recommended columns:
- `id uuid primary key`
- `changed_at timestamptz not null`
- `tenant_id text null`
- `service_name text not null`
- `schema_name text not null`
- `table_name text not null`
- `record_pk text not null`
- `operation text not null`
- `changed_by text null`
- `request_id text null`
- `correlation_id text null`
- `before_data jsonb null`
- `after_data jsonb null`
- `changed_columns text[] null`
- `checksum text null`

Supported operations:
- `INSERT`
- `UPDATE`
- `DELETE`

## Table 3: `audit.access_log`

Purpose:
- tracks access to sensitive resources and export actions

Recommended columns:
- `id uuid primary key`
- `accessed_at timestamptz not null`
- `tenant_id text null`
- `actor_id text null`
- `actor_role text null`
- `resource_type text not null`
- `resource_id text null`
- `action text not null`
- `result text not null`
- `purpose text null`
- `request_id text null`
- `ip_address inet null`
- `metadata jsonb not null default '{}'::jsonb`

## Table 4: `control.outbox_event`

Purpose:
- durable event handoff from operational services to audit consumers

Recommended columns:
- `id uuid primary key`
- `aggregate_type text not null`
- `aggregate_id text not null`
- `event_type text not null`
- `payload jsonb not null`
- `created_at timestamptz not null default now()`
- `published_at timestamptz null`
- `retry_count integer not null default 0`
- `status text not null default 'pending'`

## Naming Standard

### Event type format
`domain.entity.action`

Examples:
- `auth.user.login_failed`
- `billing.invoice.sent`
- `config.pricing.updated`

### Status values
- `success`
- `failed`
- `denied`

### Actor type values
- `user`
- `admin`
- `system`
- `job`
- `api_key`

## Design Notes

1. Keep the canonical event row wide enough for common filters.
2. Use `payload` for domain-specific details.
3. Use `metadata` for integration and tracing metadata.
4. Do not rely on JSONB only; critical filter fields should be first-class columns.
5. Keep the model audit-friendly, not app-model-perfect.
