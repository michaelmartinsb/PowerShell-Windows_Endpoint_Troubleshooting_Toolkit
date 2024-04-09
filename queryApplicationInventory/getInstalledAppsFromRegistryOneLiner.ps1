$paths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall"); $installedApps = $paths | ForEach-Object { Get-ItemProperty $_\* } | Where-Object { $_.DisplayName -ne $null } | Select-Object DisplayName, DisplayVersion | Sort-Object DisplayName; $installedApps
