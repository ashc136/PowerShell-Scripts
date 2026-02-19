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

## Disclaimer

Scripts are provided as-is. Always test in a non-production environment first.
