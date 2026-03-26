create schema if not exists audit;
create schema if not exists control;
create schema if not exists audit_views;
create schema if not exists audit_secure;

create table if not exists audit.event_log (
    id uuid not null,
    occurred_at timestamptz not null,
    ingested_at timestamptz not null default now(),
    tenant_id text null,
    service_name text not null,
    environment text not null,
    event_type text not null,
    entity_type text null,
    entity_id text null,
    actor_type text null,
    actor_id text null,
    actor_identifier text null,
    request_id text null,
    correlation_id text null,
    session_id text null,
    connection_id text null,
    approval_id text null,
    job_id text null,
    api_key_id text null,
    access_source text null,
    source_ip inet null,
    user_agent text null,
    action text null,
    status text null,
    reason text null,
    metadata jsonb not null default '{}'::jsonb,
    payload jsonb not null default '{}'::jsonb,
    primary key (occurred_at, id)
) partition by range (occurred_at);

create table if not exists audit.query_execution_log (
    id uuid not null,
    occurred_at timestamptz not null,
    ingested_at timestamptz not null default now(),
    tenant_id text null,
    service_name text not null,
    environment text not null,
    request_id text not null,
    correlation_id text null,
    execution_mode text not null,
    access_source text not null,
    user_id text null,
    api_key_id text null,
    job_id text null,
    approval_id text null,
    connection_id text not null,
    target_db_type text not null,
    target_database_name text null,
    target_schema_name text null,
    target_host_label text null,
    ssh_tunnel_used boolean not null default false,
    ssh_profile_id text null,
    statement_type text null,
    risk_level text null,
    approval_status text null,
    final_status text not null,
    query_fingerprint text not null,
    query_text_normalized text not null,
    query_hash text null,
    query_length integer null,
    parameter_count integer null,
    contains_write_operation boolean not null default false,
    contains_ddl boolean not null default false,
    contains_sensitive_pattern boolean not null default false,
    configured_timeout_ms integer null,
    configured_row_limit integer null,
    effective_timeout_ms integer null,
    effective_row_limit integer null,
    guardrail_source text null,
    requested_at timestamptz null,
    queued_at timestamptz null,
    started_at timestamptz null,
    completed_at timestamptz null,
    duration_ms integer null,
    queue_delay_ms integer null,
    rows_returned bigint null,
    rows_affected bigint null,
    result_truncated boolean not null default false,
    truncation_reason text null,
    result_size_bytes bigint null,
    commit_applied boolean null,
    plan_summary text null,
    error_class text null,
    error_code text null,
    error_message_sanitized text null,
    error_origin text null,
    retryable boolean null,
    client_ip inet null,
    user_agent text null,
    session_id text null,
    policy_version text null,
    whitelist_match_id text null,
    risk_rule_id text null,
    billable boolean null,
    usage_metric_incremented boolean null,
    billing_metric_name text null,
    billing_units numeric(18,4) null,
    metadata jsonb not null default '{}'::jsonb,
    primary key (occurred_at, id)
) partition by range (occurred_at);

create table if not exists audit.entity_change_log (
    id uuid not null,
    changed_at timestamptz not null,
    ingested_at timestamptz not null default now(),
    tenant_id text null,
    service_name text not null,
    environment text not null,
    schema_name text not null,
    table_name text not null,
    record_pk text not null,
    operation text not null,
    changed_by text null,
    request_id text null,
    correlation_id text null,
    changed_columns text[] null,
    before_data jsonb null,
    after_data jsonb null,
    checksum text null,
    metadata jsonb not null default '{}'::jsonb,
    primary key (changed_at, id)
) partition by range (changed_at);

create table if not exists audit.access_log (
    id uuid not null,
    accessed_at timestamptz not null,
    ingested_at timestamptz not null default now(),
    tenant_id text null,
    service_name text not null,
    environment text not null,
    actor_id text null,
    actor_role text null,
    resource_type text not null,
    resource_id text null,
    action text not null,
    result text not null,
    purpose text null,
    request_id text null,
    correlation_id text null,
    ip_address inet null,
    metadata jsonb not null default '{}'::jsonb,
    primary key (accessed_at, id)
) partition by range (accessed_at);

create table if not exists control.ingestion_dead_letter (
    id uuid primary key,
    received_at timestamptz not null default now(),
    producer_service text not null,
    event_id text null,
    reason text not null,
    raw_payload jsonb not null,
    retry_count integer not null default 0,
    resolved_at timestamptz null,
    resolution_note text null
);

create index if not exists idx_event_log_occurred_at
    on audit.event_log (occurred_at desc);
create index if not exists idx_event_log_tenant_time
    on audit.event_log (tenant_id, occurred_at desc);
create index if not exists idx_event_log_entity_time
    on audit.event_log (entity_type, entity_id, occurred_at desc);
create index if not exists idx_event_log_actor_time
    on audit.event_log (actor_id, occurred_at desc);
create index if not exists idx_event_log_event_type_time
    on audit.event_log (event_type, occurred_at desc);
create index if not exists idx_event_log_request_id
    on audit.event_log (request_id);
create index if not exists idx_event_log_correlation_id
    on audit.event_log (correlation_id);

create index if not exists idx_query_exec_occurred_at
    on audit.query_execution_log (occurred_at desc);
create index if not exists idx_query_exec_tenant_time
    on audit.query_execution_log (tenant_id, occurred_at desc);
create index if not exists idx_query_exec_connection_time
    on audit.query_execution_log (connection_id, occurred_at desc);
create index if not exists idx_query_exec_fingerprint_time
    on audit.query_execution_log (query_fingerprint, occurred_at desc);
create index if not exists idx_query_exec_user_time
    on audit.query_execution_log (user_id, occurred_at desc);
create index if not exists idx_query_exec_job_time
    on audit.query_execution_log (job_id, occurred_at desc);
create index if not exists idx_query_exec_request_id
    on audit.query_execution_log (request_id);
create index if not exists idx_query_exec_correlation_id
    on audit.query_execution_log (correlation_id);
create index if not exists idx_query_exec_final_status_time
    on audit.query_execution_log (final_status, occurred_at desc);

create index if not exists idx_entity_change_time
    on audit.entity_change_log (changed_at desc);
create index if not exists idx_entity_change_table_record_time
    on audit.entity_change_log (table_name, record_pk, changed_at desc);
create index if not exists idx_entity_change_changed_by_time
    on audit.entity_change_log (changed_by, changed_at desc);

create index if not exists idx_access_log_time
    on audit.access_log (accessed_at desc);
create index if not exists idx_access_log_actor_time
    on audit.access_log (actor_id, accessed_at desc);
create index if not exists idx_access_log_resource_time
    on audit.access_log (resource_type, resource_id, accessed_at desc);

create role audit_writer noinherit;
create role audit_reader noinherit;
create role audit_investigator noinherit;
create role audit_admin noinherit;
create role audit_archiver noinherit;

grant usage on schema audit to audit_writer, audit_reader, audit_investigator;
grant usage on schema control to audit_admin, audit_archiver;

grant insert on all tables in schema audit to audit_writer;
grant select on all tables in schema audit to audit_reader;
grant select on all tables in schema audit to audit_investigator;
grant select, insert, update, delete on all tables in schema control to audit_admin;

create or replace view audit_views.query_execution_safe as
select
    id,
    occurred_at,
    tenant_id,
    service_name,
    environment,
    request_id,
    correlation_id,
    execution_mode,
    access_source,
    user_id,
    job_id,
    approval_id,
    connection_id,
    target_db_type,
    statement_type,
    risk_level,
    approval_status,
    final_status,
    query_fingerprint,
    duration_ms,
    rows_returned,
    rows_affected,
    result_truncated,
    error_class,
    error_code,
    metadata
from audit.query_execution_log;
