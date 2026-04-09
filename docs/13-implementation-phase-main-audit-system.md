# 13) Implementation Phase — Main Audit System (Simple Model)

This document defines an implementation-ready phase split for the main query audit system, aligned with the simplified governance model:

- exactly one `superadmin` manages all server credentials
- server can be shared to multiple teams
- users execute query through team access
- all executions are audited
- non-SELECT requires team PIC approval per server

## 1. Final Access Model

### Roles
- `superadmin`
  - create/update/delete server credentials
  - share/unshare server to teams
  - full audit visibility
- `member`
  - execute SELECT when authorized via team access
  - submit non-SELECT approval requests

### Ownership Mapping
- `server` = managed by superadmin
- `team` = authorization boundary
- `user` = execution actor and audit identity

## 2. Core Enforcement Rules

1. `SELECT` => execute directly
2. `NON-SELECT` (`INSERT/UPDATE/DELETE/DDL`) => approval required
3. Approval scope: `team_id + server_id`
4. Every execution must bind context:
   - `user_id`, `team_id`, `server_id`
5. Audit records are append-only (immutable to members)

## 3. MVP Data Model

### users
- id (uuid, pk)
- email (unique)
- name
- role (`superadmin` | `member`)
- is_active
- created_at

### teams
- id (uuid, pk)
- name (unique)
- created_at

### team_members
- team_id (fk)
- user_id (fk)
- team_role (`member` | `lead` | `pic`)
- created_at
- pk(team_id, user_id)

### servers
- id (uuid, pk)
- name
- engine (`mysql` | `postgres`)
- host, port, database_name
- credential_encrypted
- created_by (fk users, must be superadmin)
- created_at, updated_at

### server_team_access
- server_id (fk)
- team_id (fk)
- access_level (`read_only` | `read_write`)
- created_at
- pk(server_id, team_id)

### team_server_approvers
- id (uuid, pk)
- team_id (fk)
- server_id (fk)
- approver_user_id (fk users)
- is_active
- created_at

### query_requests
- id (uuid, pk)
- requester_user_id (fk users)
- team_id (fk)
- server_id (fk)
- query_text
- query_fingerprint
- statement_type
- status (`pending` | `approved` | `rejected` | `executed` | `expired`)
- expires_at
- created_at

### query_approvals
- id (uuid, pk)
- query_request_id (fk)
- approver_user_id (fk)
- action (`approved` | `rejected`)
- note
- acted_at

### query_audit
- id (uuid, pk)
- query_request_id (nullable fk)
- user_id, team_id, server_id
- query_text_redacted
- query_fingerprint
- statement_type
- approval_required (bool)
- approved_by (nullable fk users)
- status (`success` | `failed` | `blocked`)
- error_text_redacted
- started_at, finished_at, duration_ms
- created_at

## 4. API Surface (MVP)

### Server management (superadmin only)
- `POST /servers`
- `PATCH /servers/:id`
- `DELETE /servers/:id`
- `POST /servers/:id/share-team`
- `DELETE /servers/:id/share-team/:team_id`

### Query execution
- `POST /query/execute`
  - input: `team_id`, `server_id`, `query`
  - behavior:
    - SELECT => execute + audit
    - NON-SELECT => create pending request

### Approval
- `POST /query-requests/:id/approve`
- `POST /query-requests/:id/reject`
- `POST /query-requests/:id/execute` (approved-only)

### Audit
- `GET /audit?team_id=&server_id=&user_id=&status=&from=&to=`
- `GET /query-requests?status=pending`

## 5. Phase Split

## Phase 1 — Foundation
- role model (`superadmin`/`member`)
- teams + team members
- servers + encrypted credentials + team sharing
- execution authorization gate
- SELECT execution and audit logging

Definition of done:
- members can execute SELECT only when team has server access
- all SELECT executions are recorded in audit

## Phase 2 — Approval Workflow
- statement classification
- query_requests + query_approvals
- team_server_approvers mapping
- approve/reject/execute flow
- pending request TTL expiry

Definition of done:
- non-SELECT cannot execute without valid team PIC approval

## Phase 3 — Hardening & Operations
- query normalization/fingerprint consistency
- redaction policy enforcement
- indexes + retention policy
- filterable audit API + basic usage/error metrics

Definition of done:
- system is production-ready for compliance and incident investigation baseline

## 6. Security Baseline

- only superadmin can manage credentials
- credentials stored encrypted at rest
- query text stored redacted for audit context
- approval request has TTL (e.g. 30 minutes)
- multi-statement with any non-SELECT treated as NON-SELECT
- audit trail immutable for member role

## 7. Acceptance Checklist

- [ ] only superadmin can add/update/delete server credentials
- [ ] one server can be shared across multiple teams
- [ ] member execution is bound to authorized team + server scope
- [ ] SELECT executes directly and is audited
- [ ] non-SELECT requires PIC approval per team + server
- [ ] approval actions and execution outcomes are both recorded
- [ ] audit can be filtered by user/team/server/status/time
