This PowerShell script, `Uninstall-Application.ps1`, allows you to uninstall a specified application by accepting the application name as a parameter. It searches common registry paths, including both machine-wide and user-specific locations, for the application's uninstall string and executes it to remove the application. To use the script:

1. Save it to your local machine.
2. Open PowerShell with administrative privileges.
3. Navigate to the script's location.
4. Run it with the desired application name, e.g., `.\Uninstall-Application.ps1 -AppName "MicrosoftTeams"`.

Should be used in conjunction with queryApplicationInventory in this repo in-order verify the correct app name.