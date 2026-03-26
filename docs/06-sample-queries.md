# Sample Audit Queries

## Who changed an entity?

```sql
select changed_at, service_name, table_name, record_pk, operation, changed_by
from audit.entity_change_log
where table_name = 'pricing_rules'
  and record_pk = 'rule_123'
order by changed_at desc;
```

## What happened to a business entity over time?

```sql
select occurred_at, event_type, actor_id, status, reason
from audit.event_log
where entity_type = 'order'
  and entity_id = 'ORD-100245'
order by occurred_at asc;
```

## What actions did a user perform in the last 24 hours?

```sql
select occurred_at, service_name, event_type, entity_type, entity_id, status
from audit.event_log
where actor_id = 'user_42'
  and occurred_at >= now() - interval '24 hours'
order by occurred_at desc;
```

## Which services were touched by a request or correlation ID?

```sql
select occurred_at, service_name, event_type, entity_type, entity_id, status
from audit.event_log
where correlation_id = 'corr-abc-123'
order by occurred_at asc;
```

## Who exported sensitive data?

```sql
select accessed_at, actor_id, actor_role, resource_type, resource_id, result, purpose
from audit.access_log
where action = 'export'
order by accessed_at desc;
```

## Failed admin or approval actions

```sql
select occurred_at, actor_id, event_type, entity_type, entity_id, status, reason
from audit.event_log
where actor_type = 'admin'
  and status in ('failed', 'denied')
order by occurred_at desc;
```

## Notes

These sample queries should be validated against real investigation scenarios. If repeated query patterns become common, add reporting views or materialized views rather than pushing complex repeated logic to every consumer.
