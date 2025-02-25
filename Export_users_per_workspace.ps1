# Goal - Export all users and their role from all active, non-personal workspaces. Flag the individual users.

# Permission - Tenant admin

# Parameters - fill these in before running the script!
# =====================================================

$location = ""                              # Define a location to save to
$filename = "WorkspaceUserDetails.csv"      # Define the file name

# End Parameters =======================================

# Install Power BI management module (if necessary)
if (-not(Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
    Write-Host "MicrosoftPowerBIMgmt Module does not exist, installing..."
    Install-Module -Name MicrosoftPowerBIMgmt -Force -Scope CurrentUser -SkipPublisherCheck
}

# Connect to the Power BI service
Connect-PowerBIServiceAccount

# Get a list of all active, non-personal workspaces (also excludes the system generated workspaces). 
# More info here: https://datameerkat.com/personal-workspaces-in-times-of-fabric)
$workspaces = Get-PowerBIWorkspace -Scope Organization -All -Include All | 
    Where-Object {
        $_.State -eq "Active" -and $_.Type -eq "Workspace"
    }

# Initialize counter
$totalWorkspaces = $workspaces.Count
$counter = 0

# Loop over the workspaces 
$output = foreach ($workspace in $workspaces) {
    # Show counter 
    $counter++
    Write-Host "Processing workspace $counter of $totalWorkspaces : $($workspace.Name)"

    # Get the workspace name and ID
    $WorkspaceName = $workspace.Name
    $WorkspaceId = $workspace.Id

    # Loop over the users
    foreach ($User in $workspace.Users) {
        $flag = if ($User.Identifier -match '@') { 1 } else { 0 }
        [PSCustomObject]@{
            WorkspaceName = $WorkspaceName
            WorkspaceId = $WorkspaceId
            Role = $User.AccessRight    
            Identifier = $User.Identifier
            Flag = $flag
        }
    }
} 

# Export to csv
$output | Export-CSV "$location$filename" -NoTypeInformation

# Disconnect from the Power BI service
Disconnect-PowerBIServiceAccount