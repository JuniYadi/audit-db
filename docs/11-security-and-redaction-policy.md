# Security and Redaction Policy

## Purpose

This document defines how audit data should handle secrets, credentials, personal data, and potentially dangerous content.

Audit logs are valuable for investigation, but they can also become a security liability if sensitive data is stored without controls.

## Core Principle

Capture enough detail for forensic and compliance value, but never turn the audit database into a second secrets store.

## Security Objectives

1. Prevent exposure of credentials and tokens.
2. Reduce accidental storage of PII and sensitive business data.
3. Keep audit records useful for investigations.
4. Make retention and access controls explicit.
5. Ensure the audit database is safer than the systems it observes, not weaker.

## Data Classification

Recommended categories:

### Class A: Strict secrets
Never store in plaintext in audit records.

Examples:
- raw database passwords
- SSH private keys
- webhook secret keys
- API tokens
- OAuth access tokens
- session secrets
- DSNs containing credentials
- license private material

Policy:
- must be excluded or irreversibly redacted
- may be referenced by stable identifier only

### Class B: Sensitive identifiers
Store only when necessary and prefer masking or hashing.

Examples:
- user email address
- phone number
- government identifiers
- customer account number
- internal hostnames in regulated environments

Policy:
- prefer partial masking or hashed representation
- store raw values only when explicitly justified by policy

### Class C: Operational metadata
Usually safe to store if still reviewed.

Examples:
- event type
- request ID
- correlation ID
- tenant ID
- connection ID
- status
- duration
- row counts
- worker instance ID

Policy:
- safe to store directly unless tenant policy says otherwise

### Class D: Query content and result-adjacent data
Needs conditional handling.

Examples:
- raw query text
- explain plan summaries
- error details
- export filenames
- schema names
- table names

Policy:
- must pass redaction and normalization rules before storage

## Query Text Policy

Recommended default:
- store normalized query text
- store query fingerprint
- store query hash
- do not store raw query text by default

Raw query text may be stored only when all of the following are true:
- tenant policy allows it
- environment policy allows it
- storage is encrypted at rest
- access is restricted to audited privileged readers
- redaction pass is applied first

## Redaction Rules

### Mandatory redaction targets
Redact values that look like:
- passwords
- private keys
- bearer tokens
- API keys
- cookies or session tokens
- connection strings with embedded credentials
- authorization headers
- webhook signing secrets

### Query content redaction examples
Recommended transformations:
- replace literal passwords with `[REDACTED_SECRET]`
- replace token-like strings with `[REDACTED_TOKEN]`
- replace long high-entropy blobs with `[REDACTED_HIGH_ENTROPY_VALUE]`
- replace private key bodies with `[REDACTED_PRIVATE_KEY]`

### Error message sanitization
Error payloads should be sanitized before persistence.

Remove or mask:
- DSNs
- stack traces containing secrets
- raw headers
- raw environment variables
- private host routing details if policy disallows them

Store instead:
- error class
- sanitized message
- error origin
- provider or subsystem label

## PII Handling

If the system may include personal or customer data in queries, exports, or error messages:
- minimize storage of raw values
- prefer masked display values
- prefer hashed searchable keys when exact lookup is required
- define retention shorter than general audit data if sensitive content cannot be avoided

Examples:
- email `alice@example.com` becomes `a***e@example.com`
- account number stored as hash plus masked suffix

## Access Control for Audit Data

Recommended audit DB roles:
- `audit_writer`
- `audit_reader`
- `audit_investigator`
- `audit_admin`
- `audit_archiver`

Recommended access model:
- writers can insert only
- ordinary readers see sanitized views
- investigators can access more detailed records under approval
- only a very limited admin role can manage partitions and retention

## View-Based Access Pattern

Recommended approach:
- base tables may contain higher-fidelity fields under strict protection
- normal investigation access should use sanitized SQL views
- raw encrypted fields should be isolated and decrypted only through controlled processes

Example split:
- `audit.query_execution_log` stores controlled data
- `audit_secure.query_text_store` stores encrypted raw query text if allowed
- `audit_views.query_execution_safe` exposes redacted fields for most readers

## Encryption Policy

Encryption at rest is required for:
- encrypted raw query text if stored
- any secret-adjacent payload
- webhook URLs if considered sensitive by tenant policy
- copied identifiers that could expose regulated customer data

Do not rely on encryption alone. Redaction and least privilege still apply.

## Retention Policy by Sensitivity

Suggested policy model:
- standard audit metadata: medium to long retention
- execution metadata with sanitized query detail: medium retention
- encrypted raw query text: shortest retention possible
- exported result references: short to medium retention depending on policy

If long-term compliance archive is required:
- archive sanitized data first
- archive encrypted sensitive payloads only when contractually required

## Logging Policy for Specific Features

### API Keys
- log API key ID or key fingerprint
- never log raw API key value

### SSH Tunneling
- log tunnel usage and profile reference
- never log private key contents

### Webhooks
- log endpoint ID, trigger event, response code, and delivery latency
- never log secret signing key
- mask webhook URL when necessary

### License Validation
- log license tier, status, validation result, and safe-lock transitions
- never log private signing material

### Exports
- log export ID, format, requester, destination class, and file size
- avoid storing exported content inside audit records
- if download URL exists, store short-lived reference only

## Operational Controls

Recommended controls:
- periodic scan for leaked secrets in audit tables
- automated validation tests for redaction rules
- alerting when sensitive-pattern detection fires often
- rotation procedures for any encryption keys protecting audit payloads
- restore tests to ensure encrypted historical data remains usable when needed

## Open Policy Decisions

These choices should be made explicitly before production launch:
- is raw query text allowed at all in production?
- which tenant plans are allowed to keep raw query text?
- are investigator roles permitted to decrypt stored raw text?
- what is the retention period for encrypted raw query text?
- should hostnames and schema names be treated as sensitive in self-hosted regulated environments?

## Summary

A strong audit platform should preserve truth without exposing secrets. The safest default is:
- normalized query text
- fingerprint and hash
- sanitized errors
- no raw secrets
- no plaintext credentials
- role-based access to increasingly sensitive views
