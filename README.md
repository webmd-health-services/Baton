# Overview

The "Baton" module helps separate configuration from code. Use Baton when code needs to do different things in
different environments. Put those differences in a baton.json file and use Get-CfgSetting to get a setting for an
environment.

# System Requirements

* Windows PowerShell 5.1 and .NET 4.6.1+
* PowerShell Core 6+

# Installing

To install globally:

```powershell
Install-Module -Name 'Baton'
Import-Module -Name 'Baton'
```

To install privately:

```powershell
Save-Module -Name 'Baton' -Path '.'
Import-Module -Name '.\Baton'
```

# Commands
