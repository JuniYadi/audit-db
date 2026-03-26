# Logical Architecture

## Target Architecture

The best-case architecture keeps operational systems isolated while introducing a dedicated audit platform.

### Logical Components

1. Operational databases per service
   - auth_db
   - order_db
   - billing_db
   - messaging_db

2. Audit PostgreSQL database or cluster
   - stores canonical audit events
   - stores row-level change history for critical tables
   - supports compliance and forensic investigation

3. Reporting PostgreSQL database or reporting schema
   - contains denormalized read models
   - supports dashboards and exports
   - can start in the same cluster as audit data, but split later if needed

4. Archive storage
   - object storage for older partitions
   - parquet, CSV, or compressed JSON export

## Integration Pattern

Preferred pattern:
- service transaction commits business data
- service writes outbox event in the same transaction
- publisher worker reads outbox
- publisher writes canonical audit event into audit PostgreSQL
- reporting consumers build read models if needed

## Why Outbox First

Outbox avoids distributed transaction complexity and keeps audit delivery reliable.

Benefits:
- business write and event creation stay atomic inside the service boundary
- retry is easier
- consumers can be idempotent
- operational DBs remain independent

## Hybrid Audit Capture

Use two complementary audit capture mechanisms.

### 1. Application-level business events
Used for:
- login success/failure
- approval actions
- exports
- workflow decisions
- business status changes

Strengths:
- understandable by humans
- includes actor intent, status, and reason
- best for investigations and audit reporting

### 2. Database-level change capture
Used for critical tables only:
- users
- roles
- permissions
- pricing
- settlement
- payout
- configuration

Mechanisms:
- trigger-based audit tables
- CDC pipeline if already available

Strengths:
- captures before/after state
- provides a safety net when app-level audit is incomplete
- useful for high-risk data changes

## Recommended Initial Topology

### Phase 1
- one PostgreSQL cluster
- separate schemas for `audit`, `report`, `control`, and `ref`

### Phase 2
- split reporting into its own database or cluster if load grows

### Phase 3
- keep audit on a hardened dedicated cluster with independent retention and access controls
