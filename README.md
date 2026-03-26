# audit-db

PostgreSQL audit database design notes and reference architecture.

This repository documents a best-case audit database design when the main operational databases remain separated by service/domain, while PostgreSQL is used for audit, reporting, and control-plane workloads.

## Context from PRD

The source PRD describes a commercial web-based database management platform with:
- multi-tenant cloud and single-tenant self-hosted deployment modes
- API Gateway, Auth Service, Billing/License Gateway, Redis, and Edge Query Worker
- approval workflow, scheduled jobs, notifications, and usage tracking
- detailed audit logging across UI, API, scheduler, and approval flows

In this repo, PostgreSQL is positioned as the audit/reporting/control-plane datastore around that architecture.

## Main Architecture Diagram

```mermaid
sequenceDiagram
    actor User
    participant Client as Web UI / External Client
    participant Gateway as API Gateway Service
    participant Auth as Auth Service
    participant Billing as Billing/License Gateway
    participant Cache as Redis Cache
    participant InternalDB as Internal System DB
    participant AuditDB as PostgreSQL Audit DB
    participant Worker as Edge Query Worker Service
    participant TargetDB as Target DB (PG, MySQL, etc)
    participant Scheduler as Job Scheduler Service
    participant Notify as Notification Service
    participant Reviewer as Admin / Reviewer

    User->>Client: Write query and choose Dry Run or Execute
    Client->>Gateway: Request (token/API key, query, target DB, mode)
    Gateway->>Auth: Validate session and tenant context
    Auth-->>Gateway: User ID, role, tenant ID
    Gateway->>Billing: Check license/subscription/quota
    Billing-->>Gateway: Execution allowed or safe-lock
    Gateway->>Cache: Get runtime guardrails (timeout, row limit)
    Cache-->>Gateway: Config values
    Gateway->>InternalDB: Check RBAC, whitelist, and risk policy

    alt High-risk query requires approval
        Gateway->>InternalDB: Create approval request (PENDING)
        Gateway->>Notify: Send approval notification
        Notify-->>Reviewer: Secure review link
        Reviewer->>Client: Open internal approval UI
        Client->>Gateway: Approve or reject decision
        Gateway->>InternalDB: Update approval status
        alt Rejected
            Gateway->>AuditDB: Insert audit event (approval rejected)
            Gateway-->>Client: Reject response
        else Approved
            Gateway->>AuditDB: Insert audit event (approval approved)
        end
    end

    alt Dry Run mode
        Gateway->>Worker: Forward request (EXPLAIN)
        Worker->>TargetDB: Simulate query
        TargetDB-->>Worker: Execution plan / impact estimate
        Worker-->>Gateway: Dry run result
    else Execute mode
        Gateway->>Worker: Forward request (EXECUTE)
        Worker->>TargetDB: Run query with timeout / limit
        TargetDB-->>Worker: Data / error
        Worker-->>Gateway: Execution result
    end

    Gateway->>InternalDB: Increment usage metrics and store operational state
    Gateway->>AuditDB: Insert canonical audit event and execution record
    Gateway-->>Client: Return result
    Client-->>User: Show result / error / plan

    rect rgba(245,245,245,0.5)
        Note over Scheduler,Worker: Scheduled job flow
        Scheduler->>Billing: Check license and quota
        Billing-->>Scheduler: Allowed
        Scheduler->>Worker: Trigger scheduled execution
        Worker->>TargetDB: Execute scheduled query
        TargetDB-->>Worker: Result / error
        Worker-->>Scheduler: Job status
        Scheduler->>AuditDB: Insert scheduler audit event
        alt Job failed
            Scheduler->>Notify: Send failure notification
        end
    end
```

## Docs

- `docs/01-overview.md` — architecture summary and positioning of PostgreSQL
- `docs/02-architecture.md` — logical system architecture and data flow
- `docs/03-audit-data-model.md` — canonical audit schema and table design
- `docs/04-postgres-physical-design.md` — partitioning, indexing, retention, and security
- `docs/05-rollout-plan.md` — phased implementation and rollout plan
- `docs/06-sample-queries.md` — sample investigation and reporting queries
- `docs/07-prd-gap-analysis.md` — mapping between the source PRD and the current audit DB design, including open design decisions
