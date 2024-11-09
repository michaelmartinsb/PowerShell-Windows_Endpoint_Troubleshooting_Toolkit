# Documentation for removeAllPrinterInstances.ps1

---

## **Table of Contents**

1. [Introduction](#introduction)
2. [Script Overview](#script-overview)
3. [Prerequisites and Dependencies](#prerequisites-and-dependencies)
4. [Configuration Parameters](#configuration-parameters)
5. [Script Breakdown](#script-breakdown)
   - [Importing Modules](#importing-modules)
   - [Error Recovery Functions](#error-recovery-functions)
   - [Verification Functions](#verification-functions)
   - [Manual Driver Removal Function](#manual-driver-removal-function)
   - [Print Spooler Service Management](#print-spooler-service-management)
6. [Step-by-Step Execution](#step-by-step-execution)
   - [Step 1: Remove Installed Printers](#step-1-remove-installed-printers)
   - [Step 2: Remove Printer Devices](#step-2-remove-printer-devices)
   - [Step 3: Remove Printers via WMI](#step-3-remove-printers-via-wmi)
   - [Step 4: Remove Printer-Related Registry Entries](#step-4-remove-printer-related-registry-entries)
   - [Step 5: Scrub User Profiles](#step-5-scrub-user-profiles)
   - [Step 6: Clean Up Printer Drivers](#step-6-clean-up-printer-drivers)
   - [Step 7: Clean Up Print Queues](#step-7-clean-up-print-queues)
   - [Step 8: Clear Cached Group Policy Objects](#step-8-clear-cached-group-policy-objects)
   - [Step 9: Handle Network Printers](#step-9-handle-network-printers)
   - [Step 10: Restart Print Spooler Service](#step-10-restart-print-spooler-service)
   - [Step 11: Verify Removal](#step-11-verify-removal)
   - [Final Step: System Restart (Optional)](#final-step-system-restart-optional)
7. [Error Handling and Logging](#error-handling-and-logging)
8. [Security Considerations](#security-considerations)
9. [Testing and Deployment](#testing-and-deployment)
10. [Usage Instructions](#usage-instructions)
11. [Conclusion](#conclusion)
12. [Appendix: Full Script](#appendix-full-script)

---

## **Introduction**

This documentation provides a comprehensive overview of a PowerShell script designed to remove all printers and associated configurations from a Windows PC, including user-specific settings. The script is intended for use in environments where a complete reset of printer configurations is necessary, such as in troubleshooting persistent printing issues or preparing systems for redeployment.

---

## **Script Overview**

The script performs the following actions:

1. **Removes all installed printers** using multiple methods to ensure completeness.
2. **Removes printer devices** listed in Device Manager.
3. **Deletes printer entries via WMI** (Windows Management Instrumentation).
4. **Backs up and removes printer-related registry entries**, including those in user profiles.
5. **Cleans up printer drivers**, with fallback methods for stubborn drivers.
6. **Cleans up print queues** and removes any pending print jobs.
7. **Clears cached Group Policy Objects (GPOs)** related to printers.
8. **Scrubs all user profiles** for printer and GPO settings.
9. **Handles network printers** with special cleanup procedures.
10. **Restarts the Print Spooler service** with retry logic.
11. **Verifies the removal** of printers and drivers.
12. **Logs all actions** for auditing and troubleshooting.
13. **Optionally restarts the system** after execution.

---

## **Prerequisites and Dependencies**

- **Administrative Privileges:** The script must be run with System privileges due to the elevated permissions required for modifying system settings and registry keys.

- **PowerShell Version:** The script requires PowerShell 3.0 or higher.

- **Modules:**
  - **PrintManagement Module:** Used for printer management cmdlets. The script includes logic to install and import this module if not already present.
  
- **Utilities:**
  - **`pnputil.exe`:** Used for manual driver removal when standard methods fail. This utility is included in Windows 7 and later.

---

## **Configuration Parameters**

At the beginning of the script, several parameters can be adjusted to modify its behavior:

```powershell
# Set to $true to automatically restart the computer after script execution
$AutoRestart = $false

# Define whether to clean up printer drivers after printer removal
$CleanupDrivers = $true

# Define whether to clean up print queues after printer removal
$CleanupPrintQueues = $true

# Define whether to force restoration of registry backups on errors
$Force = $false
```

- **`$AutoRestart`:** If set to `$true`, the system will automatically restart after the script completes.
- **`$CleanupDrivers`:** Controls whether printer drivers are removed.
- **`$CleanupPrintQueues`:** Controls whether print queues and pending jobs are removed.
- **`$Force`:** If set to `$true`, the script will attempt to restore registry backups upon encountering errors.

---

## **Script Breakdown**

### **Importing Modules**

The script ensures that the necessary modules are available, particularly the `PrintManagement` module:

```powershell
function Ensure-PrintManagementModule {
    # Function body to check and install the module
}
```

This function checks if the module is available and installs it if necessary using `Install-WindowsFeature`.

### **Error Recovery Functions**

To handle potential errors, the script includes functions to restore registry backups:

```powershell
function Restore-RegistryBackup {
    # Function body to restore registry backups
}
```

### **Verification Functions**

After execution, the script verifies that printers and drivers have been removed:

```powershell
function Test-PrinterRemoval {
    # Function body to check for remaining printers and drivers
}
```

### **Manual Driver Removal Function**

For stubborn printer drivers that cannot be removed using standard methods, the script includes a manual removal function:

```powershell
function Remove-PrinterDriverManually {
    # Uses pnputil.exe to remove driver packages
}
```

### **Print Spooler Service Management**

The script manages the Print Spooler service with retry logic to ensure it's running when necessary:

```powershell
function Restart-PrintSpooler {
    # Function body with retry logic for restarting the spooler service
}
```

---

## **Step-by-Step Execution**

### **Step 1: Remove Installed Printers**

- **Objective:** Remove all printers installed on the system using `Get-Printer` and `Remove-Printer`.
- **Process:**
  - Retrieves a list of installed printers.
  - Iterates over each printer and attempts to remove it.
- **Error Handling:** Catches and logs any errors during removal.

### **Step 2: Remove Printer Devices**

- **Objective:** Remove printer devices listed in Device Manager using `Get-PnpDevice` and `Remove-PnpDevice`.
- **Process:**
  - Enumerates all printer devices.
  - Removes each device without confirmation.
- **Error Handling:** Adjusts `$ErrorActionPreference` to continue on non-critical errors.

### **Step 3: Remove Printers via WMI**

- **Objective:** Remove printer entries using WMI to ensure all instances are covered.
- **Process:**
  - Retrieves printers via `Get-WmiObject` (class `Win32_Printer`).
  - Deletes each printer using the `Delete()` method.
- **Error Handling:** Logs errors and continues processing remaining printers.

### **Step 4: Remove Printer-Related Registry Entries**

- **Objective:** Clean up registry entries related to printers.
- **Process:**
  - Defines a list of registry paths to be removed.
  - Backs up each registry key before deletion.
  - Handles the special case of `HKLM:\SYSTEM\CurrentControlSet\Enum\SWD\PRINTENUM` by deleting subkeys.
- **Error Handling:**
  - Attempts to restore from backups if errors occur and `$Force` is set to `$true`.

### **Step 5: Scrub User Profiles**

- **Objective:** Remove printer and GPO settings from all user profiles.
- **Process:**
  - Retrieves all user profiles.
  - For each profile:
    - Loads the user's registry hive.
    - Removes printer-related registry entries.
    - Removes GPO-related registry entries.
    - Unloads the registry hive.
- **Error Handling:** Logs errors and ensures the registry hive is unloaded.

### **Step 6: Clean Up Printer Drivers**

- **Objective:** Remove printer drivers from the system.
- **Process:**
  - Retrieves a list of installed printer drivers.
  - Excludes essential drivers (e.g., "Microsoft Print To PDF").
  - Attempts to remove each driver using `Remove-PrinterDriver`.
  - If standard removal fails, uses `Remove-PrinterDriverManually`.
- **Error Handling:** Logs errors and provides fallback methods for driver removal.

### **Step 7: Clean Up Print Queues**

- **Objective:** Remove print queues and pending print jobs.
- **Process:**
  - Ensures the `PrintManagement` module is available.
  - Retrieves all print queues.
  - Removes all print jobs from each queue.
  - Removes the print queue itself.
- **Error Handling:** Logs errors during removal.

### **Step 8: Clear Cached Group Policy Objects**

- **Objective:** Clear GPO caches to remove any residual printer policies.
- **Process:**
  - Deletes contents of the `GroupPolicy` directory, excluding essential directories.
  - Clears temporary GPO cache paths.
  - Clears the Resultant Set of Policy (RSOP) cache.
- **Error Handling:** Logs errors and continues processing.

### **Step 9: Handle Network Printers**

- **Objective:** Remove network printers and associated configurations.
- **Process:**
  - Identifies network printers.
  - Removes each network printer.
  - Performs additional cleanup if necessary (e.g., network mappings).
- **Error Handling:** Logs errors during removal.

### **Step 10: Restart Print Spooler Service**

- **Objective:** Ensure the Print Spooler service is running properly.
- **Process:**
  - Uses the `Restart-PrintSpooler` function with retry logic to stop and start the service.
- **Error Handling:** Attempts multiple times before logging an error.

### **Step 11: Verify Removal**

- **Objective:** Confirm that all printers and drivers have been removed.
- **Process:**
  - Calls the `Test-PrinterRemoval` function.
  - Logs remaining printers and drivers if any are found.
- **Error Handling:** Provides a summary of the verification process.

### **Final Step: System Restart (Optional)**

- **Objective:** Optionally restart the system to complete the cleanup.
- **Process:**
  - Checks the `$AutoRestart` parameter.
  - Initiates a system restart if enabled.
- **Error Handling:** Logs errors if the restart fails.

---

## **Error Handling and Logging**

- **Logging Mechanism:**
  - The script uses `Start-Transcript` to record all output.
  - Custom `Write-Log` function adds timestamps and log levels to messages.
  - Log files are stored in `$env:ProgramData\PrinterRemovalLogs` with a timestamp.

- **Error Handling:**
  - Uses `try`/`catch` blocks extensively to handle exceptions.
  - Logs errors and warnings without terminating the script prematurely.
  - Provides fallback methods (e.g., manual driver removal) when standard methods fail.

---

## **Security Considerations**

- **Registry Modifications:**
  - The script modifies and deletes registry keys, which can impact system stability.
  - Backups are created before deletion to allow restoration if necessary.

- **Administrative Privileges:**
  - Required for modifying system settings and should be granted cautiously.
  - Ensure the script is reviewed and approved by security personnel before deployment.

- **Manual Driver Removal:**
  - Uses `pnputil.exe` to remove driver packages, which can affect other devices if misused.
  - The script targets specific drivers to minimize risk.

---

## **Testing and Deployment**

- **Testing Environment:**
  - Test the script in a controlled, non-production environment.
  - Verify that all intended actions are performed without adverse effects.

- **Deployment Recommendations:**
  - Review the script for compliance with organizational policies.
  - Adjust configuration parameters as needed.
  - Ensure that backups are in place before running the script on production systems.

---

## **Usage Instructions**

1. **Copy the Script:**
   - Copy the full script provided in the appendix into a `.ps1` file (e.g., `PrinterRemoval.ps1`).

2. **Adjust Configuration Parameters:**
   - Modify the parameters at the top of the script to suit your needs.

3. **Run as Administrator:**
   - Open PowerShell with administrative privileges.
   - Navigate to the directory containing the script.

4. **Execution Policy:**
   - Ensure that the execution policy allows script execution:
     ```powershell
     Set-ExecutionPolicy RemoteSigned -Scope Process
     ```

5. **Execute the Script:**
   - Run the script:
     ```powershell
     .\PrinterRemoval.ps1
     ```

6. **Monitor the Output:**
   - The script will output logs to the console and write detailed logs to the log file.

7. **Review Logs:**
   - After execution, review the logs in `$env:ProgramData\PrinterRemovalLogs` for any errors or warnings.

8. **Restart the System (If Applicable):**
   - If `$AutoRestart` is set to `$false`, consider restarting the system manually to complete the cleanup.

---

## **Conclusion**

This script provides a comprehensive solution for removing printers and associated configurations from a Windows PC. By following the steps outlined and considering the security implications, administrators can use this script to reset printing configurations effectively.

---

---

## **Contact Information**

N/A

---

**End of Documentation**