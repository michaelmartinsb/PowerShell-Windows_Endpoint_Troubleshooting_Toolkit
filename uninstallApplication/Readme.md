### Updated README for Uninstall-Application PowerShell Script

This PowerShell script, `Uninstall-Application.ps1`, allows you to uninstall a specified application by accepting the application name as a parameter. It searches common registry paths, including both machine-wide and user-specific locations, for the application's uninstall string and executes it to remove the application. The script handles multiple instances of the same application and attempts silent uninstallation using common flags.

#### Key Features:
- **Handles Multiple Instances**: Uninstalls all instances of the specified application.
- **Silent Uninstallation**: Attempts to uninstall applications silently using `/S` or `/quiet /qn` flags.
- **Comprehensive Logging**: Logs all actions and errors to a text file in `C:\temp`.

### Usage Instructions:
1. **Save the Script**:
   Save the script to your local machine as `Uninstall-Application.ps1`.

2. **Open PowerShell with Administrative Privileges**:
   Right-click on the Start menu and select "Windows PowerShell (Admin)" or "Windows Terminal (Admin)".

3. **Navigate to the Script's Location**:
   Use `cd` command to navigate to the directory where you saved the script.

4. **Run the Script**:
   Execute the script with the desired application name. For example, to uninstall "MicrosoftTeams", run:
   ```powershell
   .\Uninstall-Application.ps1 -AppName "MicrosoftTeams"
   ```

5. **Check the Logs**:
   The script logs its actions to `C:\temp\uninstall_log.txt`. Check this file for detailed information and troubleshooting.

### Prerequisites:
- Ensure you have PowerShell 5.0 or later.
- Run PowerShell with administrative privileges to allow the script to uninstall applications.

### Notes:
- **Silent Uninstallation**: The script attempts silent uninstallation for better automation. If silent uninstallation fails, it falls back to a normal uninstallation.
- **Multiple Instances**: The script handles multiple instances of the application and uninstalls each one found.
- **Log Directory**: If the `C:\temp` directory does not exist, the script will create it along with the log file.

### Example:
To uninstall "Teams Machine-Wide Installer", you would run:
```powershell
.\Uninstall-Application.ps1 -AppName "Teams Machine-Wide Installer"
```

### Verification:
Use in conjunction with `queryApplicationInventory` in this repository to verify the correct application name before running the uninstallation script.