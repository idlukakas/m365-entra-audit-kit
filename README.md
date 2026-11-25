# M365 & Entra ID Cert-Auth Audit Kit

Production-grade, **read-only** PowerShell toolkit for auditing Microsoft 365 licenses, Entra ID hygiene, and Intune device compliance using **X.509 certificate-based OAuth2 (`RS256` JWT client assertion)** — zero hardcoded client secrets, zero interactive logins.

Built by [Lucas Menezes Sá Teles](https://www.linkedin.com/in/lucasmsteles/) · Fixed-price M365 / Entra / Intune sprints at [teles-cloud-ops.vercel.app](https://teles-cloud-ops.vercel.app).

## Why This Toolkit?
- **No brittle client secrets:** Signs an `RS256` JWT assertion locally with your X.509 certificate (`New-CertAuthGraphSession.ps1`) and exchanges it for a Microsoft Graph bearer token.
- **Strictly read-only:** Only requires least-privilege `Application` read permissions (`Organization.Read.All`, `DeviceManagementManagedDevices.Read.All`).
- **Actionable CSV + Markdown output:** Instantly surfaces unassigned/idle paid SKUs, stale Intune devices (`>45 days`), and non-compliant endpoints.

## Files Included
| File | Purpose |
| :--- | :--- |
| `New-CertAuthGraphSession.ps1` | Signs an `RS256` JWT `client_assertion` with an X.509 `.pfx` certificate and returns a Microsoft Graph bearer token. |
| `Invoke-M365TenantHealthAudit.ps1` | Runs paginated Microsoft Graph queries for `subscribedSkus` and `managedDevices`, exporting `license_summary.csv`, `intune_devices.csv`, `intune_stale_devices.csv`, and `SUMMARY.md`. |
| `DELIVERY_REPORT_TEMPLATE.md` | Executive handover report template for IT leadership and security audits. |

## Quick Start

```powershell
# 1. Authenticate with X.509 certificate (no client secret)
. .\New-CertAuthGraphSession.ps1
$pwd = Read-Host "PFX Password" -AsSecureString
$session = New-CertAuthGraphSession `
    -TenantId "<your-tenant-id>" `
    -ClientId "<your-app-client-id>" `
    -PfxPath ".\graph-audit.pfx" `
    -PfxPassword $pwd

# 2. Run read-only M365 & Intune health audit
.\Invoke-M365TenantHealthAudit.ps1 `
    -AccessToken $session.AccessToken `
    -StaleDays 45 `
    -OutputDir ".\audit-output"
```

## Sample Output (`SUMMARY.md`)

```markdown
# M365 & Intune Tenant Audit Summary

- Total SKUs analyzed: 14
- Total Intune managed devices: 620
- Stale devices (>45 days since sync): 31
- Non-compliant devices: 12
```

## Need Custom Automation or Hardening?
For custom Entra ID / Intune automations, Conditional Access audits, SAML 2.0 SSO, or FortiGate-to-Cloud VPN sprints, see [teles-cloud-ops.vercel.app](https://teles-cloud-ops.vercel.app) or email `lucasmenezes.teles@gmail.com`.

## License
MIT License — see `LICENSE`.
