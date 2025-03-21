# Goal - Deploy content from one environment to another using a deployment pipeline.

# Permission - Admin of the deployment pipeline, at least contributor in the workspaces.

# Parameters - fill these in before running the script!
# =====================================================
$reportID = "ID of your report" # Reports can have the same name, so to avoid confusion, it is best to give the ID 
$pipelineDisplayName = "Name of your pipeline" # The display name of the pipeline (pipeline names are unique, so no need to look up the ID)
$currentEnv = "PRD" # Current environment of the report 
$targetEnv = "DEV" # Target environment of the report
$baseWorkspaceName = "Base workspace name" # The base name of the workspace without any suffix

# End Parameters =======================================

# Parameter Validation
# =====================================================
# Validate if Report ID is given
if ([string]::IsNullOrEmpty($reportID)) {
 Write-Host "Error: Report ID is required."
 exit
}

# Validate if Pipeline name is given
if ([string]::IsNullOrEmpty($pipelineDisplayName)) {
 Write-Host "Error: Pipeline name is required."
 exit
}

# Validate current environment
if ($currentEnv -notin @("DEV", "UAT", "PRD")) {
 Write-Host "Error: Invalid current environment '$currentEnv'. Valid environments are 'DEV', 'UAT', 'PRD'."
 exit
}

# Validate target environment
if ($targetEnv -notin @("DEV", "UAT", "PRD")) {
 Write-Host "Error: Invalid target environment '$targetEnv'. Valid environments are 'DEV', 'UAT', 'PRD'."
 exit
}

if ($targetEnv -eq $currentEnv) {
    Write-Host "Error: Target environment cannot be the same as the current environment"
    exit
}

# Install necessary modules
# =====================================================
# Install Power BI management module (if necessary)
if (-not(Get-Module -ListAvailable -Name MicrosoftPowerBIMgmt)) {
 Write-Host "MicrosoftPowerBIMgmt Module does not exist, installing..."
 Install-Module -Name MicrosoftPowerBIMgmt -Force -Scope CurrentUser -SkipPublisherCheck
}

# Login to the Power BI service
Connect-PowerBIServiceAccount

# Get the pipeline according to pipelineName
$pipelines = Invoke-PowerBIRestMethod -Url "pipelines" -Method Get | ConvertFrom-Json 

$pipeline = $pipelines.Value | Where-Object displayName -eq $pipelineDisplayName
if(!$pipeline) {
 Write-Host "A pipeline with the requested name was not found"
 return
}

# Get the stages of the pipeline
$stages = Invoke-PowerBIRestMethod -Url "pipelines/$($pipeline.Id)/stages" -Method Get | ConvertFrom-Json

# Find the current stage based on currentEnv
$currentStage = $stages.value | Where-Object { $_.workspaceName -eq $baseWorkspaceName -or $_.workspaceName.Contains("[$currentEnv]") }
if(!$currentStage) {
 Write-Host "Current environment '$currentEnv' not found"
 return
}

# Find the target stage based on targetEnv
$targetStage = $stages.value | Where-Object { $_.workspaceName -eq $baseWorkspaceName -or $_.workspaceName -eq $_.workspaceName.Contains("[$targetEnv]") }
if(!$targetStage) {
 Write-Host "Target environment '$targetEnv' not found"
 return
}

# Determine deployment direction
$isBackwardDeployment = $currentStage.order -gt $targetStage.order

# Define body of the API call
$DeployBody = 
    @{ 
        sourceStageOrder = $currentStage.order
        isBackwardDeployment = $isBackwardDeployment
        reports = @(
            @{sourceId = $reportID }
        ) 
        options = @{
            allowCreateArtifact = $true
            allowOverwriteArtifact = $true
        }
    } | ConvertTo-Json

# Deploy from current to target environment
$deployUrl = "pipelines/{0}/Deploy/" -f $pipeline.Id

try {
    Invoke-PowerBIRestMethod -Url $deployUrl -Method Post -Body $DeployBody -ContentType "application/json" -ErrorAction Stop
    Write-Host "Success: Report was succesfully deployed from $($currentStage.workspaceName) to $($targetStage.workspaceName)."
}
catch {
    Write-Host "Error: Report was not deployed."
}

# Disconnect from the Power BI service
Disconnect-PowerBIServiceAccount