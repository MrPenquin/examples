---
name: incident-runbook
description: Acme's production incident runbook — severity definitions, who to page, the comms cadence, and the steps to declare, mitigate, and resolve an incident. Use when a user reports an outage, a page fires, error rates spike, or someone asks how to handle / declare an incident.
---

# Acme Incident Runbook

Use this when production is degraded or down.

## Severity
- **SEV1** — full outage or data loss. Page on-call + EM immediately.
- **SEV2** — major feature down or severe degradation. Page on-call.
- **SEV3** — minor/contained. Handle in business hours.

## Declare
1. Open an incident channel: `#inc-YYYYMMDD-<short-slug>`.
2. Post the one-line impact statement and current severity.
3. Assign an Incident Commander (IC). The IC coordinates; they do not debug.

## Mitigate (in priority order)
1. **Stop the bleeding** — roll back the last deploy or disable the offending
   feature flag before root-causing.
2. Confirm mitigation with the relevant dashboard/SLO.
3. Only then investigate root cause.

## Comms cadence
- SEV1: status update every 15 min. SEV2: every 30 min.
- Updates go in the incident channel and the public status page.

## Resolve
1. Confirm metrics back to baseline for one full cadence interval.
2. Downgrade severity, then close.
3. Schedule a blameless postmortem within 3 business days.

Never skip the rollback step to "investigate first" — mitigate, then diagnose.
