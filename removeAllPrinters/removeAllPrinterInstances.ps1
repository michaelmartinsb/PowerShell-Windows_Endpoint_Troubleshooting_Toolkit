<#
.SYNOPSIS
    Comprehensive script to remove all printers and associated configurations from the PC, including user-specific settings.

.DESCRIPTION
    This script performs the following actions:
    1. Removes all installed printers.
    2. Removes all printer devices listed in Device Manager.
    3. Removes printers via WMI (Win32_Printer).
    4. Backs up and removes printer-related registry entries.
    5. Cleans up printer drivers associated with removed printers.
    6. Cleans up print queues associated with removed printers.
    7. Clears cached Group Policy Objects (GPOs) comprehensively.
    8. Iteratively scrubs all user profiles for printer and GPO settings.
    9. Handles network printers with special cleanup.
    10. Restarts the Print Spooler service with retry logic.
    11. Verifies the removal of printers and drivers.
    12. Logs all actions for auditing and troubleshooting.
    13. Optionally restarts the system after execution.

.AUTHOR
    Developed by Michael Martins-Baptista with assistance from ChatGPT o1 and Claude.

.NOTES
    - Run this script as System.
    - Ensure you have adequate backups before making system changes.
    - Tested on PowerShell 5.1 and later.
#>

# ----------------------------
# Configuration Parameters
# ----------------------------

# Set to $true to automatically restart the computer after script execution
$AutoRestart = $false

# Define whether to clean up printer drivers after printer removal
$CleanupDrivers = $true

# Define whether to clean up print queues after printer removal
$CleanupPrintQueues = $true

# Define whether to force restoration of registry backups on errors
$Force = $false

# ----------------------------
# Configuration
# ----------------------------

# Define the log file path with timestamp
$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$logFile = "$env:ProgramData\PrinterRemovalLogs\PrinterRemovalLog_$timestamp.txt"

# Ensure the log directory exists
$logDirectory = Split-Path -Path $logFile
if (-not (Test-Path -Path $logDirectory)) {
    New-Item -Path $logDirectory -ItemType Directory -Force | Out-Null
}

# Start logging
Start-Transcript -Path $logFile -Append

# Function to write log with timestamp
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )
    $timeStamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $formattedMessage = "$timeStamp [$Level] $Message"
    Write-Output $formattedMessage
}

# ----------------------------
# Import Necessary Modules
# ----------------------------

# Function to install the PrintManagement module if not present
function Ensure-PrintManagementModule {
    if (-not (Get-Module -Name PrintManagement -ListAvailable)) {
        Write-Log "PrintManagement module not found. Attempting to install..." "WARN"
        try {
            # Install the Print-Services feature along with management tools
            Install-WindowsFeature Print-Services -IncludeManagementTools -ErrorAction Stop
            Import-Module PrintManagement -ErrorAction Stop
            Write-Log "PrintManagement module installed and imported successfully." "INFO"
        } catch {
            Write-Log "Failed to install PrintManagement module: $($_.Exception.Message)" "ERROR"
        }
    } else {
        Import-Module PrintManagement -ErrorAction SilentlyContinue
        Write-Log "PrintManagement module imported successfully." "INFO"
    }
}

# Ensure the PrintManagement module is available
Ensure-PrintManagementModule

# ----------------------------
# Error Recovery Function
# ----------------------------

function Restore-RegistryBackup {
    param(
        [string]$BackupPath,
        [string]$OriginalPath
    )
    if (Test-Path $BackupPath) {
        try {
            reg import $BackupPath | Out-Null
            Write-Log "Restored registry from backup '$BackupPath' to '$OriginalPath'." "INFO"
        } catch {
            Write-Log "Failed to restore registry from backup '$BackupPath': $($_.Exception.Message)" "ERROR"
        }
    } else {
        Write-Log "Backup file '$BackupPath' does not exist. Cannot restore registry path '$OriginalPath'." "WARN"
    }
}

# ----------------------------
# Verification Function
# ----------------------------

function Test-PrinterRemoval {
    $remainingPrinters = @(Get-Printer -ErrorAction SilentlyContinue)
    $remainingDrivers = @(Get-PrinterDriver -ErrorAction SilentlyContinue)
    return ($remainingPrinters.Count -eq 0) -and ($remainingDrivers.Count -eq 0)
}

# ----------------------------
# Manual Driver Removal Function
# ----------------------------

function Remove-PrinterDriverManually {
    param(
        [Parameter(Mandatory = $true)]
        [string]$DriverName
    )

    Write-Log "Attempting manual removal of printer driver: $DriverName" "WARN"

    try {
        # Get the driver info using Win32_PrinterDriver
        $driverInfo = Get-WmiObject -Class Win32_PrinterDriver -Filter "Name='$DriverName'" -ErrorAction Stop
        if ($driverInfo) {
            $infPath = $driverInfo.InfName
            Write-Log "Driver INF Path: $infPath" "INFO"

            # Find the published name using pnputil
            $pnputilOutput = pnputil.exe /enum-drivers
            $driverLines = $pnputilOutput | Select-String -Pattern "Published Name|Original Name"

            $publishedName = $null
            for ($i = 0; $i -lt $driverLines.Count; $i += 2) {
                $pubName = $driverLines[$i].Line -replace 'Published Name : ', ''
                $origName = $driverLines[$i + 1].Line -replace 'Original Name  : ', ''
                if ($origName -eq $infPath) {
                    $publishedName = $pubName
                    break
                }
            }

            if ($publishedName) {
                # Remove the driver package using pnputil
                pnputil.exe /delete-driver $publishedName /uninstall /force
                Write-Log "Manually removed printer driver: $DriverName" "INFO"
            } else {
                Write-Log "Could not find published name for driver '$DriverName'." "ERROR"
            }
        } else {
            Write-Log "Driver information not found for '$DriverName'." "ERROR"
        }
    } catch {
        Write-Log "Manual removal failed for printer driver '$DriverName': $($_.Exception.Message)" "ERROR"
    }
}

# ----------------------------
# Function to Restart Print Spooler with Retry Logic
# ----------------------------

function Restart-PrintSpooler {
    param(
        [int]$RetryCount = 3
    )

    for ($i = 1; $i -le $RetryCount; $i++) {
        try {
            Stop-Service -Name "Spooler" -Force -ErrorAction Stop
            Start-Sleep -Seconds 2
            Start-Service -Name "Spooler" -ErrorAction Stop
            $serviceStatus = Get-Service -Name "Spooler"
            if ($serviceStatus.Status -eq 'Running') {
                Write-Log "Print Spooler service restarted successfully." "INFO"
                return $true
            } else {
                Write-Log "Print Spooler service is in '$($serviceStatus.Status)' state." "WARN"
            }
        } catch {
            Write-Log "Attempt $i of $RetryCount to restart spooler failed: $($_.Exception.Message)" "WARN"
            Start-Sleep -Seconds 5
        }
    }
    Write-Log "Failed to restart Print Spooler service after $RetryCount attempts." "ERROR"
    return $false
}

# ----------------------------
# Preliminary Checks
# ----------------------------

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 3) {
    Write-Log "This script requires PowerShell version 3.0 or higher." "ERROR"
    Stop-Transcript
    exit 1
}

# Check for Administrator privileges
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
    Write-Log "This script must be run as Administrator." "ERROR"
    Stop-Transcript
    exit 1
}

# ----------------------------
# Step 1: Remove All Installed Printers via Get-Printer
# ----------------------------
Write-Log "Step 1: Removing all installed printers via Get-Printer..."

try {
    $printers = Get-Printer -ErrorAction Stop
    if ($printers.Count -eq 0) {
        Write-Log "No printers found to remove via Get-Printer." "INFO"
    } else {
        foreach ($printer in $printers) {
            try {
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-Log "Removed printer: $($printer.Name)" "INFO"
            } catch {
                Write-Log "Failed to remove printer '$($printer.Name)': $($_.Exception.Message)" "ERROR"
            }
        }
    }
} catch {
    Write-Log "Error retrieving printers via Get-Printer: $($_.Exception.Message)" "ERROR"
}

# ----------------------------
# Step 2: Remove All Printer Devices via Get-PnpDevice
# ----------------------------
Write-Log "Step 2: Removing all printer devices via Get-PnpDevice..."

$previousErrorActionPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

try {
    # Enumerate all printer devices, including those not listed by Get-Printer
    $printerDevices = Get-PnpDevice -Class Printer -ErrorAction Continue | Where-Object { $_ -ne $null }

    if ($printerDevices.Count -eq 0) {
        Write-Log "No printer devices found to remove via Get-PnpDevice." "INFO"
    } else {
        foreach ($device in $printerDevices) {
            try {
                # Remove the printer device without confirmation
                Remove-PnpDevice -InstanceId $device.InstanceId -Confirm:$false -ErrorAction Stop
                Write-Log "Removed printer device: $($device.Name)" "INFO"
            } catch {
                Write-Log "Failed to remove printer device '$($device.Name)': $($_.Exception.Message)" "ERROR"
            }
        }
    }
} catch {
    Write-Log "Non-critical error in PnP device enumeration: $($_.Exception.Message)" "WARN"
}

$ErrorActionPreference = $previousErrorActionPreference

# ----------------------------
# Step 3: Remove All Printers via Get-WmiObject (Win32_Printer)
# ----------------------------
Write-Log "Step 3: Removing all printers via Get-WmiObject (Win32_Printer)..."

try {
    $wmiPrinters = Get-WmiObject -Class Win32_Printer -ErrorAction Stop
    if ($wmiPrinters.Count -eq 0) {
        Write-Log "No printers found to remove via Win32_Printer." "INFO"
    } else {
        foreach ($printer in $wmiPrinters) {
            try {
                $result = $printer.Delete()
                if ($result.ReturnValue -eq 0) {
                    Write-Log "Removed printer via WMI: $($printer.Name)" "INFO"
                } else {
                    Write-Log "WMI failed to remove printer '$($printer.Name)'. Return Value: $($result.ReturnValue)" "ERROR"
                }
            } catch {
                Write-Log "Failed to remove printer via WMI '$($printer.Name)': $($_.Exception.Message)" "ERROR"
            }
        }
    }
} catch {
    Write-Log "Error retrieving printers via Win32_Printer: $($_.Exception.Message)" "ERROR"
}

# ----------------------------
# Step 4: Remove Printer-Related Registry Entries
# ----------------------------
Write-Log "Step 4: Removing printer-related registry entries..."

# Define registry paths related to printers
$printerRegistryPaths = @(
    "HKCU:\Printers\Connections",
    "HKCU:\Printers\ConvertUserDevModesCounts",
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Devices",
    "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\PrinterPorts",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\Client Side Rendering Print Provider\Servers",
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Print\Providers\",
    "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Printers",
    "HKLM:\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Print\Providers\",
    "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM"  # Added key location
)

foreach ($regPath in $printerRegistryPaths) {
    if (Test-Path $regPath) {
        try {
            # Backup the registry key
            $safeRegPath = $regPath -replace ":", ""
            $backupPath = "$env:ProgramData\PrinterRemovalLogs\RegBackup_$($safeRegPath.Replace('\', '_'))_$timestamp.reg"
            reg export $regPath $backupPath /y | Out-Null
            Write-Log "Backup created for '$regPath' at '$backupPath'" "INFO"

            # Special handling for HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM
            if ($regPath -eq "HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM") {
                Write-Log "Deleting subkeys under '$regPath'..." "INFO"
                try {
                    $subKeys = Get-ChildItem -Path $regPath -ErrorAction Stop
                    foreach ($subKey in $subKeys) {
                        $subKeyPath = Join-Path -Path $regPath -ChildPath $subKey.PSChildName
                        if (Test-Path $subKeyPath) {
                            try {
                                # Remove the subkey without changing ownership
                                Remove-Item -Path $subKeyPath -Recurse -Force -ErrorAction Stop
                                Write-Log "Deleted subkey: $subKeyPath" "INFO"
                            } catch {
                                Write-Log "Failed to delete subkey '$subKeyPath': $($_.Exception.Message)" "ERROR"
                            }
                        }
                    }
                } catch {
                    Write-Log "Failed to enumerate subkeys under '$regPath': $($_.Exception.Message)" "ERROR"
                }
            } else {
                # Remove the registry key
                Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
                Write-Log "Removed registry path: $regPath" "INFO"
            }
        } catch {
            Write-Log "Failed to process registry path '$regPath': $($_.Exception.Message)" "ERROR"
            if ($Force) {
                Restore-RegistryBackup -BackupPath $backupPath -OriginalPath $regPath
            }
        }
    } else {
        Write-Log "Registry path not found: $regPath" "WARN"
    }
}

# ----------------------------
# Step 5: Scrubbing All User Profiles for Printer and GPO Settings
# ----------------------------
Write-Log "Step 5: Scrubbing all user profiles for printer and GPO settings..."

# Get all user profiles
$userProfiles = Get-WmiObject -Class Win32_UserProfile | Where-Object { $_.Special -eq $false -and $_.Loaded -eq $false }

$totalProfiles = $userProfiles.Count
$currentProfileNumber = 0

foreach ($profile in $userProfiles) {
    $currentProfileNumber++
    $userSID = $profile.SID
    $userPath = $profile.LocalPath

    Write-Log "Processing user profile: SID=${userSID}, Path=${userPath}" "INFO"

    # Define path to ntuser.dat
    $ntUserPath = Join-Path -Path $userPath -ChildPath "NTUSER.DAT"

    if (-not (Test-Path $ntUserPath)) {
        Write-Log "NTUSER.DAT not found for user SID=${userSID} at path ${ntUserPath}" "WARN"
        continue
    }

    # Define a temporary hive name
    $tempHive = "TempUserHive_$userSID"

    try {
        # Load the user's registry hive with timeout
        $loadSuccess = $false
        $timeout = 30 # seconds
        $stopWatch = [System.Diagnostics.Stopwatch]::StartNew()

        while (-not $loadSuccess -and $stopWatch.Elapsed.TotalSeconds -lt $timeout) {
            try {
                reg load "HKU\$tempHive" "$ntUserPath" | Out-Null
                $loadSuccess = $true
            } catch {
                Start-Sleep -Seconds 1
            }
        }

        if (-not $loadSuccess) {
            Write-Log "Failed to load registry hive for user SID=${userSID} within $timeout seconds." "ERROR"
            continue
        }

        Write-Log "Loaded registry hive for user SID=${userSID} as HKU\$tempHive" "INFO"

        # Progress Reporting
        Write-Progress -Activity "Processing User Profiles" -Status "Profile $currentProfileNumber of $totalProfiles" -PercentComplete (($currentProfileNumber / $totalProfiles) * 100)

        # Define user-specific printer registry paths
        $userPrinterRegistryPaths = @(
            "HKU:\$tempHive\Printers\Connections",
            "HKU:\$tempHive\Printers\ConvertUserDevModesCounts",
            "HKU:\$tempHive\Software\Microsoft\Windows NT\CurrentVersion\Devices",
            "HKU:\$tempHive\Software\Microsoft\Windows NT\CurrentVersion\PrinterPorts"
        )

        foreach ($userRegPath in $userPrinterRegistryPaths) {
            if (Test-Path $userRegPath) {
                try {
                    # Backup the registry key
                    $safeUserRegPath = $userRegPath -replace ":", ""
                    $backupPathUser = "$env:ProgramData\PrinterRemovalLogs\UserRegBackup_$($safeUserRegPath.Replace('\', '_'))_$timestamp.reg"
                    reg export $userRegPath $backupPathUser /y | Out-Null
                    Write-Log "Backup created for user registry path '$userRegPath' at '$backupPathUser'" "INFO"

                    # Remove the registry key
                    Remove-Item -Path $userRegPath -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed user registry path: $userRegPath" "INFO"
                } catch {
                    Write-Log "Failed to remove user registry path '$userRegPath': $($_.Exception.Message)" "ERROR"
                    if ($Force) {
                        Restore-RegistryBackup -BackupPath $backupPathUser -OriginalPath $userRegPath
                    }
                }
            } else {
                Write-Log "User registry path not found: $userRegPath" "WARN"
            }
        }

        # Define user-specific GPO registry paths
        $userGPORegistryPaths = @(
            "HKU:\$tempHive\Software\Policies",
            "HKU:\$tempHive\Software\Microsoft\Windows\CurrentVersion\Policies"
        )

        foreach ($userGPORegPath in $userGPORegistryPaths) {
            if (Test-Path $userGPORegPath) {
                try {
                    # Backup the registry key
                    $safeUserGPORegPath = $userGPORegPath -replace ":", ""
                    $backupPathUserGPO = "$env:ProgramData\PrinterRemovalLogs\UserGPOBackup_$($safeUserGPORegPath.Replace('\', '_'))_$timestamp.reg"
                    reg export $userGPORegPath $backupPathUserGPO /y | Out-Null
                    Write-Log "Backup created for user GPO registry path '$userGPORegPath' at '$backupPathUserGPO'" "INFO"

                    # Remove the registry key
                    Remove-Item -Path $userGPORegPath -Recurse -Force -ErrorAction Stop
                    Write-Log "Removed user GPO registry path: $userGPORegPath" "INFO"
                } catch {
                    Write-Log "Failed to remove user GPO registry path '$userGPORegPath': $($_.Exception.Message)" "ERROR"
                    if ($Force) {
                        Restore-RegistryBackup -BackupPath $backupPathUserGPO -OriginalPath $userGPORegPath
                    }
                }
            } else {
                Write-Log "User GPO registry path not found: $userGPORegPath" "WARN"
            }
        }
    } catch {
        Write-Log "Error processing user profile SID=${userSID}: $($_.Exception.Message)" "ERROR"
    } finally {
        # Ensure the registry hive is unloaded
        try {
            reg unload "HKU\$tempHive" | Out-Null
            Write-Log "Unloaded registry hive for user SID=${userSID}" "INFO"
        } catch {
            Write-Log "Failed to unload registry hive for user SID=${userSID}: $($_.Exception.Message)" "ERROR"
        }
    }
}

# ----------------------------
# Step 6: Clean Up Printer Drivers
# ----------------------------
if ($CleanupDrivers) {
    Write-Log "Step 6: Cleaning up printer drivers..."

    # Step 6A: Retrieve the list of printer drivers
    try {
        $printerDrivers = Get-PrinterDriver -ErrorAction Stop
        Write-Log "Retrieved $($printerDrivers.Count) printer drivers for cleanup." "INFO"
    } catch {
        Write-Log "Failed to retrieve printer drivers: $($_.Exception.Message)" "ERROR"
        $printerDrivers = @()
    }

    if ($printerDrivers.Count -gt 0) {
        # Exclude essential/system drivers
        $excludedDrivers = @(
            "Microsoft Print To PDF",
            "Microsoft XPS Document Writer",
            "Microsoft enhanced Point and Print compatibility driver"
        )

        foreach ($driver in $printerDrivers) {
            if ($excludedDrivers -contains $driver.Name) {
                Write-Log "Skipping protected driver: $($driver.Name)" "INFO"
                continue
            }

            # Attempt removal with both methods
            try {
                Remove-PrinterDriver -Name $driver.Name -ErrorAction Stop
                Write-Log "Removed printer driver: $($driver.Name)" "INFO"
            } catch {
                Write-Log "Standard removal failed for $($driver.Name), attempting manual removal..." "WARN"
                Remove-PrinterDriverManually -DriverName $driver.Name
            }
        }

        # Restart the Print Spooler service using the retry logic function
        Restart-PrintSpooler -RetryCount 3
    } else {
        Write-Log "No printer drivers found to remove." "INFO"
    }
} else {
    Write-Log "Printer driver cleanup is disabled." "INFO"
}

# ----------------------------
# Step 7: Clean Up Print Queues
# ----------------------------
if ($CleanupPrintQueues) {
    Write-Log "Step 7: Cleaning up print queues..."

    # Ensure the PrintManagement module is loaded for Get-PrintQueue
    Ensure-PrintManagementModule

    # Check if Get-PrintQueue is available
    if (-not (Get-Command -Name Get-PrintQueue -ErrorAction SilentlyContinue)) {
        Write-Log "Get-PrintQueue cmdlet is not available. Skipping print queue cleanup." "ERROR"
    } else {
        try {
            # Get all print queues
            $printQueues = Get-PrintQueue -ErrorAction Stop

            if ($printQueues.Count -eq 0) {
                Write-Log "No print queues found to remove." "INFO"
            } else {
                foreach ($queue in $printQueues) {
                    try {
                        # Remove all print jobs in the queue
                        $printJobs = Get-PrintJob -PrinterName $queue.Name -ErrorAction SilentlyContinue
                        foreach ($job in $printJobs) {
                            Remove-PrintJob -PrinterName $queue.Name -ID $job.ID -ErrorAction Stop
                            Write-Log "Removed print job ID $($job.ID) from queue '$($queue.Name)'." "INFO"
                        }

                        # Remove the print queue
                        Remove-PrintQueue -Name $queue.Name -ErrorAction Stop
                        Write-Log "Removed print queue: $($queue.Name)" "INFO"
                    } catch {
                        Write-Log "Failed to remove print queue '$($queue.Name)': $($_.Exception.Message)" "ERROR"
                    }
                }
            }
        } catch {
            Write-Log "Error retrieving print queues: $($_.Exception.Message)" "ERROR"
        }
    }
} else {
    Write-Log "Print queue cleanup is disabled." "INFO"
}

# ----------------------------
# Step 8: Comprehensive Clearing of Cached Group Policy Objects
# ----------------------------
Write-Log "Step 8: Comprehensive clearing of cached Group Policy Objects (GPOs)..."

try {
    # Remove all contents within the GroupPolicy directory except for 'Machine' and 'User'
    # These directories are essential for current policies and should not be removed

    $gpoCachePath = "C:\Windows\System32\GroupPolicy"

    if (Test-Path $gpoCachePath) {
        # First, delete all subdirectories except 'Machine' and 'User'
        Get-ChildItem -Path $gpoCachePath -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -notin @("Machine", "User") } | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed GPO cache directory: $($_.FullName)" "INFO"
            } catch {
                Write-Log "Failed to remove GPO cache directory '$($_.FullName)': $($_.Exception.Message)" "WARN"
            }
        }

        # Remove all files within the GroupPolicy directory
        Get-ChildItem -Path $gpoCachePath -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            try {
                Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
                Write-Log "Removed GPO cache file: $($_.FullName)" "INFO"
            } catch {
                Write-Log "Failed to remove GPO cache file '$($_.FullName)': $($_.Exception.Message)" "WARN"
            }
        }

        # Additionally, clear the cache for Group Policy Client Side Extensions
        # This includes temporary files and cached data in other locations

        # Define additional temporary GPO cache paths
        $tempGPOPaths = @(
            "$env:LOCALAPPDATA\GroupPolicy",
            "$env:LOCALAPPDATA\Microsoft\GroupPolicy",
            "$env:ProgramData\Microsoft\GroupPolicy"
        )

        foreach ($tempPath in $tempGPOPaths) {
            if (Test-Path $tempPath) {
                try {
                    Remove-Item -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Log "Cleared temporary GPO cache at: $tempPath" "INFO"
                } catch {
                    Write-Log "Failed to clear temporary GPO cache at '$tempPath': $($_.Exception.Message)" "WARN"
                }
            } else {
                Write-Log "Temporary GPO cache path not found: $tempPath" "WARN"
            }
        }

        # Clear the Resultant Set of Policy (RSOP) cache
        $rsopCachePath = "C:\Windows\System32\GroupPolicy\DataStore"
        if (Test-Path $rsopCachePath) {
            try {
                Remove-Item -Path "$rsopCachePath\*" -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Cleared RSOP cache at: $rsopCachePath" "INFO"
            } catch {
                Write-Log "Failed to clear RSOP cache at '$rsopCachePath': $($_.Exception.Message)" "WARN"
            }
        } else {
            Write-Log "RSOP cache path not found: $rsopCachePath" "WARN"
        }

        Write-Log "Comprehensive GPO cache clearing completed." "INFO"
    } else {
        Write-Log "GroupPolicy directory not found: $gpoCachePath" "WARN"
    }
} catch {
    Write-Log "Failed during comprehensive GPO cache clearing: $($_.Exception.Message)" "ERROR"
}

# ----------------------------
# Step 9: Handle Network Printers
# ----------------------------
Write-Log "Step 9: Handling network printers with special cleanup..."

try {
    # Identify network printers
    $networkPrinters = Get-Printer | Where-Object { $_.Type -eq 'Connection' }

    if ($networkPrinters.Count -eq 0) {
        Write-Log "No network printers found to remove." "INFO"
    } else {
        foreach ($printer in $networkPrinters) {
            try {
                # Remove the network printer
                Remove-Printer -Name $printer.Name -ErrorAction Stop
                Write-Log "Removed network printer: $($printer.Name)" "INFO"

                # Additional cleanup for network mappings if necessary
                # Example: Remove any persistent network mappings or credentials
                # This depends on how the network printers are mapped

                # Example: Remove persistent connection via net use (if applicable)
                # Get the port name associated with the printer
                $port = Get-PrinterPort -Name $printer.PortName -ErrorAction SilentlyContinue
                if ($port) {
                    # Assuming network printers use TCP/IP ports with IP addresses
                    if ($port.Name -match 'TCP/IP Port') {
                        # Extract IP address or server name from port name or properties
                        # Placeholder for additional cleanup
                        Write-Log "Additional network mapping cleanup required for port: $($port.Name)" "INFO"
                    }
                }
            } catch {
                Write-Log "Failed to remove network printer '$($printer.Name)': $($_.Exception.Message)" "ERROR"
            }
        }
    }
} catch {
    Write-Log "Error handling network printers: $($_.Exception.Message)" "ERROR"
}

# ----------------------------
# Step 10: Restart the Print Spooler Service
# ----------------------------
Write-Log "Step 10: Restarting the Print Spooler service..."

# Restart the Print Spooler service using the retry logic function
Restart-PrintSpooler -RetryCount 3

# ----------------------------
# Step 11: Verify Removal
# ----------------------------
Write-Log "Step 11: Verifying removal of printers and drivers..."

try {
    $removalSuccess = Test-PrinterRemoval
    if ($removalSuccess) {
        Write-Log "All printers and printer drivers have been successfully removed." "INFO"
    } else {
        Write-Log "Some printers or printer drivers are still present." "WARN"
        # Optionally, list remaining printers and drivers
        $remainingPrinters = Get-Printer -ErrorAction SilentlyContinue
        if ($remainingPrinters.Count -gt 0) {
            $printerList = ($remainingPrinters | Select-Object -ExpandProperty Name) -join ", "
            Write-Log "Remaining Printers: $printerList" "WARN"
        }

        $remainingDrivers = Get-PrinterDriver -ErrorAction SilentlyContinue
        if ($remainingDrivers.Count -gt 0) {
            $driverList = ($remainingDrivers | Select-Object -ExpandProperty Name) -join ", "
            Write-Log "Remaining Printer Drivers: $driverList" "WARN"
        }
    }
} catch {
    Write-Log "Error during verification: $($_.Exception.Message)" "ERROR"
}

# ----------------------------
# Final Step: System Restart (Optional)
# ----------------------------
Write-Log "Final Step: System Restart Decision."

if ($AutoRestart) {
    try {
        Write-Log "AutoRestart is enabled. Initiating system restart..." "INFO"
        Restart-Computer -Force -ErrorAction Stop
    } catch {
        Write-Log "Failed to restart the system: $($_.Exception.Message)" "ERROR"
    }
} else {
    Write-Log "AutoRestart is disabled. Please restart the system manually if required." "INFO"
}

# Stop logging
Stop-Transcript
