# Rollout Plan

## Phase 1: Audit Requirement Mapping

Objectives:
- identify critical business actions
- identify high-risk tables
- define retention and investigation requirements

Outputs:
- list of auditable events
- list of critical tables for row-level change capture
- list of consumers: security, ops, compliance, finance, support

## Phase 2: Classification and Ownership

Objectives:
- classify data into operational, audit, reporting, and archive concerns
- define service ownership clearly

Outputs:
- source system matrix
- ownership matrix
- sensitivity and retention matrix

## Phase 3: Canonical Audit Contract

Objectives:
- standardize event names and payload rules across services
- define mandatory columns and tracing fields

Mandatory fields:
- event ID
- occurred_at
- service_name
- event_type
- actor context
- entity context
- request_id
- correlation_id

## Phase 4: Ingestion Pipeline

Recommended best-case setup:
- business audit events via outbox + publisher
- row-level critical table capture via trigger or CDC

Success criteria:
- idempotent publisher
- retry support
- duplicate-safe ingestion into audit PostgreSQL

## Phase 5: Physical PostgreSQL Setup

Deliverables:
- schemas created
- partitioned audit tables
- baseline indexes
- role and privilege model
- retention and archive jobs

## Phase 6: Reporting and Investigation Layer

Deliverables:
- sample forensic queries
- denormalized reporting views
- dashboard-ready datasets
- export templates for audit review

## Phase 7: Security and Governance

Deliverables:
- read-only auditor role
- insert-only writer role
- backup and restore validation
- archive integrity checks
- change management process for schema updates

## Phase 8: Controlled Rollout

Suggested rollout sequence:
1. onboard one or two critical domains first
2. validate write volume and query patterns
3. validate retention and archive jobs
4. review missing fields with real incident investigations
5. expand to additional services

## Minimum Viable First Version

A practical first version can be:
- one PostgreSQL cluster
- one `audit` schema plus `control`
- partitioned `event_log`
- partitioned `entity_change_log`
- outbox-based ingestion
- basic retention policy
- basic archive script
- read-only audit access for investigators
