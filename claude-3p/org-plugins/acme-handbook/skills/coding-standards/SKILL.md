---
name: coding-standards
description: Acme's engineering coding standards — language choices, the approved-dependency list, logging, error handling, and review expectations. Use whenever writing or reviewing code in an Acme repo, choosing a library, or deciding how to structure a service.
---

# Acme Coding Standards

Apply these whenever you write or review code in an Acme repository.

## Languages
- **Services**: TypeScript (Node 20+) or Go 1.22+. No new Python services without a DevEx exception.
- **Infra**: Terraform only. No hand-clicked cloud resources.

## Approved dependencies
Only add libraries from the approved list. If a needed library is not listed,
stop and tell the user to file a DevEx exception — do not add it silently.

- HTTP: `undici` (TS), `net/http` (Go)
- Validation: `zod` (TS)
- Logging: `pino` (TS), `slog` (Go) — structured JSON only, never `console.log`
- Testing: `vitest` (TS), standard `testing` (Go)

## Error handling
- Never swallow errors. Log with context and rethrow, or return a typed error.
- User-facing messages must not leak stack traces or internal identifiers.

## Secrets
- No secrets in source, env files, or logs. Fetch from the `acme-vault` MCP at runtime.
- This is enforced by the `acme-security-review` plugin's write guardrail.

## Reviews
- Every change touching auth, crypto, input handling, or IaC must pass
  `/acme-secreview` before merge.
