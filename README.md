# PowerShell Scripts

A collection of PowerShell scripts for Azure, Microsoft 365, and enterprise security administration.

---

## Scripts

###  Clean-MDI-Sensor.ps1

Fully removes all residual components of the Microsoft Defender for Identity sensor
(formerly Azure Advanced Threat Protection Sensor) when the standard uninstaller fails.

**Use this when:**
- Sensor is showing Disconnected in the MDI portal and cannot be repaired
- Previous uninstall left behind services or registry keys blocking reinstallation
- Sensor is stuck on an old version (common on Server 2016)

**What it does:**
- Stops and deletes MDI sensor services (supports both old and new service names)
- Finds and removes all registry GUIDs associated with the sensor
- Cleans up Package Cache folders
- Removes the installation directory
- Generates a timestamped log file for auditing

**Supported OS:** Windows Server 2016, 2019, 2022

**Usage:**
```powershell
.\Clean-MDI-Sensor.ps1
```
Run as Administrator. You will be prompted to confirm each major action.

---

---

### Get-EntraPasswordExpiry.ps1

Checks password expiry status for a specific user in Entra ID (Azure AD) using Microsoft Graph.

**Use this when:**

- You need to quickly check when a user's password expires
- Helpdesk staff need to verify password status without full admin portal access
- You want to identify accounts with password expiration disabled

**What it does:**

- Accepts UPN, SAMAccountName, or email address as input
- Queries Microsoft Graph for last password change date and password policies
- Calculates expiry date based on your org's password age policy (default: 90 days)
- Displays account enabled/disabled status and days remaining
- Handles cloud-only and AD-synced accounts

**Prerequisites:** Microsoft.Graph PowerShell module

**Usage:**
```
.\Get-EntraPasswordExpiry.ps1
```

Run as a user with `User.Read.All` Graph permission. You will be prompted to enter a username.

> **Note:** Update `$orgAgeDays` in the script to match your tenant's password expiry policy if it differs from 90 days.

## Disclaimer

Scripts are provided as-is. Always test in a non-production environment first.
