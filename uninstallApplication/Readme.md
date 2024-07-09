### README for Uninstall-Application PowerShell Script

This PowerShell script, `Uninstall-Application.ps1`, allows you to uninstall a specified application by accepting the application name as a parameter. It searches common registry paths, including both machine-wide and user-specific locations, for the application's uninstall string and executes it to remove the application. The script also handles modern AppX/MSIX packages using PowerShell cmdlets. Both traditional and modern packages are uninstalled silently.

#### Key Features:
- **Handles Both Traditional and Modern Packages**: Uninstalls applications installed via MSI and AppX/MSIX.
- **Silent Uninstallation**: Ensures the process is silent, using common silent uninstallation flags and cmdlets.
- **Case-Insensitive Matching**: Targets the specified application name without regard to character case.
- **Comprehensive Logging**: Logs all actions and errors to a text file in `C:\temp`.

### Usage Instructions:
1. **Save the Script**:
   Save the script to your local machine as `Uninstall-Application.ps1`.

2. **Open PowerShell with Administrative Privileges**:
   Right-click on the Start menu and select "Windows PowerShell (Admin)" or "Windows Terminal (Admin)".

3. **Navigate to the Script's Location**:
   Use `cd` command to navigate to the directory where you saved the script.

4. **Run the Script**:
   Execute the script with the exact application name. For example, to uninstall "MicrosoftTeams", run:
   ```powershell
   .\Uninstall-Application.ps1 -AppName "MicrosoftTeams"
   ```

5. **Check the Logs**:
   The script logs its actions to `C:\temp\uninstall_log.txt`. Check this file for detailed information and troubleshooting.

### Prerequisites:
- Ensure you have PowerShell 5.0 or later.
- Run PowerShell with administrative privileges to allow the script to uninstall applications.

### Example:
To uninstall "Teams Machine-Wide Installer", you would run:
```powershell
.\Uninstall-Application.ps1 -AppName "Teams Machine-Wide Installer"
```

### Verification:
Use in conjunction with `queryApplicationInventory` in this repository to verify the correct application name before running the uninstallation script.

### Notes:
- **Silent Uninstallation**: The script attempts silent uninstallation for better automation.
- **Log Directory**: If the `C:\temp` directory does not exist, the script will create it along with the log file.