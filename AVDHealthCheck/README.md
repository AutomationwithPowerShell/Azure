
# 🔍 Azure WVD Hostpool & FileShare HealthCheck Script

**Author:** Naveen Jogga Ram  
**Version:** 1.0  
**Created On:** 09-Jan-2023  
**Last Updated:** 14-Mar-2023  

## 📘 Overview

This PowerShell script performs a **comprehensive health check** of:
- **Azure WVD (Windows Virtual Desktop) Hostpool Virtual Machines**
- **Azure Fileshare & NetApp File Shares**

It generates a **detailed HTML report** containing VM states, drain mode info, and storage health summaries — which is optionally sent to a **Citrix distribution list via email**.

## 📦 Features

- ✅ Collects VM availability, drain mode, and reboot status  
- ✅ Tracks Unavailable and Upgrading VMs  
- ✅ Automatically restarts unavailable VMs  
- ✅ Generates a color-coded HTML health report  
- ✅ Reports Azure File Share usage/quota/available space  
- ✅ Supports DR NetApp File Share volume monitoring  
- ✅ Sends optional HTML email reports  

## 📋 Prerequisites

- PowerShell 5.1+
- Azure PowerShell Modules:
  - `Az`
  - `Microsoft.RDInfra.RDPowershell`
  - `Az.NetAppFiles`
- Access to Azure subscription with:
  - **Reader or Contributor role** on WVD Host Pools
  - **Storage Account Contributor** role for Fileshares
- FileShare path for logs/reports (`\\filesharepath\Automation\AzureHealthCheck`)
- Scheduled Task (optional) via SCCM or Task Scheduler

## 🛠 Setup Instructions

### 1. **Install Required Modules**
```powershell
Install-Module -Name Az -Force
Install-Module -Name Microsoft.RDInfra.RDPowershell -Force
Install-Module -Name Az.NetAppFiles -Force
```

### 2. **Update Script Configuration**
- Update file share path, Azure subscription name, hostpool filters, and admin emails.

### 3. **Run the Script**
```powershell
Set-ExecutionPolicy Bypass -Scope CurrentUser -Force
.\AzureHealthCheck_V4.ps1
```

## 📊 Report Format

HTML report includes:
- Hostpool Summary (with Total/Available/Drain/Unavailable VMs)
- Azure File Share health
- DR File Share details

## 📧 Email Notification (Optional)
Configure email section inside script.

## 🔁 Change Log

| Date       | Description                                               |
|------------|-----------------------------------------------------------|
| 13-Mar-23  | Optimized execution, added DrainModeON                   |
| 14-Mar-23  | Cosmetic updates, DR Fileshare utilization added          |

## 📧 Support

- **Created By:** [Naveen Ram](mailto:Naveen.Ram@bankfab.com)  
- **Support:** [Citrix Support](mailto:CitrixSupport@bankfab.com)  
- **Azure Portal:** [https://portal.azure.com](https://portal.azure.com)
