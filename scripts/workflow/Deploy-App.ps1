<#
.SYNOPSIS
    Deploys a compiled Business Central app package (.app file) to a container.
.DESCRIPTION
    This script deploys a compiled Business Central app package (.app file) to a container by:
    1. Taking parameters for compiled app file path (.app file), container name, and app type (main/test)
    2. Verifying the container exists and is running using structured Docker output formats
    3. Using a single BcContainerHelper Publish-BcContainerApp command with -replacePackageId to automatically handle existing app versions
    4. Applying publishing settings from the configuration (scope, sync mode, skip verification)
    5. Using -skipVerification, -sync, -install, -syncMode, -useDevEndpoint, and -replacePackageId parameters for optimal deployment
    6. Returning a strongly-typed [pscustomobject] with deployment results

    This simplified approach eliminates the need for manual dependency checking and multi-step uninstall/unpublish operations.
    The script uses common utility functions from Common-Functions.ps1 and configuration from TDDConfig.psd1 for consistent functionality.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER AppPath
    Path to the compiled app file (.app) to deploy. If not specified, uses the path from configuration based on AppType.
.PARAMETER ContainerName
    Name of the container to deploy the app to. If not specified, uses the container name from configuration.
.PARAMETER AppType
    Type of app to deploy. Valid values are "Main" and "Test". Default is "Main".
.EXAMPLE
    .\scripts\Deploy-App.ps1
    # Deploys the main app using default paths from configuration
.EXAMPLE
    .\scripts\Deploy-App.ps1 -AppType "Test"
    # Deploys the test app using default paths from configuration
.EXAMPLE
    .\scripts\Deploy-App.ps1 -AppPath ".\build\output\app.app" -ContainerName "mycontainer" -AppType "Main"
    # Deploys the specified app to the specified container
.NOTES
    This script is part of the Business Central TDD workflow.

    Author: AI Assistant
    Date: 2023-11-15
    Version: 2.0

    Change Log:
    1.0 - Initial version with complex multi-step deployment approach
    2.0 - Refactored to use single Publish-BcContainerApp command with -replacePackageId for simplified deployment
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [string]$AppPath,

    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [ValidateSet("Main", "Test")]
    [string]$AppType = "Main"
)

#region Script Initialization

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Get the script directory
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Fallback if $MyInvocation.MyCommand.Path is empty
    $scriptPath = $PSCommandPath
}

if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Hard-coded fallback if both are empty
    $scriptDir = "d:\repos\bctddflow\scripts"
    Write-Warning "Using hard-coded script directory: $scriptDir"
} else {
    $scriptDir = Split-Path -Parent $scriptPath
}

# Import Common-Functions.ps1
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the lib folder."
    exit 1
}
. $commonFunctionsPath

# Import Get-TDDConfiguration.ps1
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-Error "Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath. Make sure the script exists in the lib folder."
    exit 1
}

# Load configuration
$configParams = @{}
if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $configParams['ConfigPath'] = $ConfigPath
}

$config = & $getTDDConfigPath @configParams

if (-not $config) {
    Write-ErrorMessage "Failed to load configuration. Please check the configuration file and try again."
    exit 1
}

# Apply script behavior settings from configuration
if ($config.ScriptSettings) {
    if ($config.ScriptSettings.ErrorActionPreference) {
        $ErrorActionPreference = $config.ScriptSettings.ErrorActionPreference
    }
    if ($config.ScriptSettings.VerboseOutput -eq $true) {
        $VerbosePreference = 'Continue'
    } else {
        $VerbosePreference = 'SilentlyContinue'
    }
    if ($config.ScriptSettings.WarningActionPreference) {
        $WarningPreference = $config.ScriptSettings.WarningActionPreference
    }
    if ($config.ScriptSettings.InformationPreference) {
        $InformationPreference = $config.ScriptSettings.InformationPreference
    }
    if ($config.ScriptSettings.ProgressPreference) {
        $ProgressPreference = $config.ScriptSettings.ProgressPreference
    }
}

#endregion

#region Functions

function Invoke-DeployApp {
    <#
    .SYNOPSIS
        Main function to deploy an app to a Business Central container.
    .DESCRIPTION
        Deploys a compiled app package (.app file) to a Business Central container.
    .PARAMETER Config
        The configuration object.
    .PARAMETER AppPath
        Path to the compiled app file (.app) to deploy.
    .PARAMETER ContainerName
        Name of the container to deploy the app to.
    .PARAMETER AppType
        Type of app to deploy. Valid values are "Main" and "Test".
    .OUTPUTS
        PSCustomObject. Returns an object with the results of the operation.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,

        [Parameter(Mandatory = $false)]
        [string]$AppPath,

        [Parameter(Mandatory = $false)]
        [string]$ContainerName,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Main", "Test")]
        [string]$AppType = "Main"
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        Success = $false
        Message = ""
        AppType = $AppType
        AppPath = $null
        ContainerName = $null
        PublishingScope = $null
        SyncMode = $null
        AppInfo = $null
        Timestamp = Get-Date
    }

    try {
        # Determine app path based on app type if not specified
        if ([string]::IsNullOrWhiteSpace($AppPath)) {
            $outputDir = Resolve-TDDPath -Path $Config.OutputPaths.AppOutput

            # Find the most recent .app file for the specified app type
            $appFiles = Get-ChildItem -Path $outputDir -Filter "*.app" | Where-Object { $_.Name -match "\.app$" }

            if ($appFiles.Count -eq 0) {
                throw "No .app files found in output directory: $outputDir"
            }

            # For test app, look for files with "Test" in the name
            if ($AppType -eq "Test") {
                $testAppFiles = $appFiles | Where-Object { $_.Name -match "Test" }
                if ($testAppFiles.Count -gt 0) {
                    # Use the most recent test app file
                    $appFile = $testAppFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                } else {
                    throw "No test app files found in output directory: $outputDir"
                }
            } else {
                # For main app, exclude files with "Test" in the name
                $mainAppFiles = $appFiles | Where-Object { $_.Name -notmatch "Test" }
                if ($mainAppFiles.Count -gt 0) {
                    # Use the most recent main app file
                    $appFile = $mainAppFiles | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
                } else {
                    throw "No main app files found in output directory: $outputDir"
                }
            }

            $AppPath = $appFile.FullName
        }

        # Use container name from configuration if not specified
        if ([string]::IsNullOrWhiteSpace($ContainerName)) {
            $ContainerName = $Config.ContainerName
        }

        # Resolve app path
        $resolvedAppPath = Resolve-TDDPath -Path $AppPath

        # Update result with resolved paths
        $result.AppPath = $resolvedAppPath
        $result.ContainerName = $ContainerName
        $result.PublishingScope = $Config.Publishing.Scope
        $result.SyncMode = $Config.Publishing.SyncMode

        # Display section header
        Write-SectionHeader "Deploying $AppType App" -ForegroundColor Cyan -DecorationType Underline

        # Display information about the operation
        Write-InfoMessage "Starting deployment with the following parameters:"
        Write-InfoMessage "  App Type: $AppType"
        Write-InfoMessage "  App Path: $resolvedAppPath"
        Write-InfoMessage "  Container Name: $ContainerName"
        Write-InfoMessage "  Publishing Scope: $($Config.Publishing.Scope)"
        Write-InfoMessage "  Sync Mode: $($Config.Publishing.SyncMode)"

        # Check if app file exists
        if (-not (Test-Path -Path $resolvedAppPath -PathType Leaf)) {
            throw "App file not found: $resolvedAppPath"
        }

        # Verify Docker is running
        if (-not (Test-DockerRunning)) {
            throw "Docker is not running. Please start Docker and try again."
        }

        # Verify container exists using structured Docker output
        if (-not (Test-DockerContainerExists -ContainerName $ContainerName)) {
            throw "Container '$ContainerName' does not exist. Please create the container and try again."
        }

        # Verify container is running using structured Docker output
        if (-not (Test-DockerContainerRunning -ContainerName $ContainerName)) {
            throw "Container '$ContainerName' is not running. Please start the container and try again."
        }

        # Get container information using structured Docker output
        $containerInfo = Get-DockerContainerInfo -ContainerName $ContainerName
        if (-not $containerInfo) {
            throw "Failed to get container information for '$ContainerName'."
        }

        # Import BcContainerHelper module
        # Check if we should suppress verbose output from BcContainerHelper
        $suppressVerbose = $false
        if ($config.ScriptSettings -and $config.ScriptSettings.SuppressBcContainerHelperVerbose) {
            $suppressVerbose = $config.ScriptSettings.SuppressBcContainerHelperVerbose
        }

        if (-not (Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose)) {
            throw "BcContainerHelper module is not installed or cannot be imported. Please install the module and try again."
        }

        # Check if required BcContainerHelper commands are available
        $requiredCommands = @("Publish-BcContainerApp")
        foreach ($command in $requiredCommands) {
            if (-not (Test-BcContainerHelperCommandAvailable -CommandName $command)) {
                throw "Required BcContainerHelper command '$command' is not available. Please update the BcContainerHelper module and try again."
            }
        }

        # Extract basic app information for logging purposes (optional, for display only)
        $appInfo = Invoke-ScriptWithErrorHandling -ScriptBlock {
            try {
                # Try to get basic app info for logging
                $appInfo = Get-NavAppInfoFromAppFile -Path $resolvedAppPath
                return $appInfo
            } catch {
                # If we can't get app info, continue anyway - it's just for logging
                Write-InfoMessage "Could not extract app information for logging purposes, continuing with deployment..."
                return $null
            }
        } -ErrorMessage "Failed to get app information from file" -ContinueOnError

        if ($appInfo) {
            Write-InfoMessage "App details: $($appInfo.Publisher)_$($appInfo.Name)_$($appInfo.Version)"
        }

        # Publish the app to the container using simplified single-command approach
        Write-InfoMessage "Publishing app to container using single command with automatic replacement..."

        $publishSuccess = Invoke-ScriptWithErrorHandling -ScriptBlock {
            # Create default credentials for container authentication
            $defaultPasswordString = if ($Config.TestSettings.DefaultPassword) {
                $Config.TestSettings.DefaultPassword
            } else {
                "P@ssw0rd"
            }
            # Required for BC container authentication
            # PSScriptAnalyzer suppression: This is required for BC container authentication
            # SuppressMessage: PSAvoidUsingConvertToSecureStringWithPlainText - Required for BC container authentication
            $defaultPassword = ConvertTo-SecureString $defaultPasswordString -AsPlainText -Force
            $credential = New-Object System.Management.Automation.PSCredential("admin", $defaultPassword)

            # Use single Publish-BcContainerApp command with replacePackageId for automatic replacement
            $publishResult = Publish-BcContainerApp `
                -containerName $ContainerName `
                -appFile $resolvedAppPath `
                -credential $credential `
                -skipVerification:$true `
                -sync `
                -install `
                -syncMode $Config.Publishing.SyncMode `
                -scope $Config.Publishing.Scope `
                -useDevEndpoint `
                -replacePackageId

            return $publishResult
        } -ErrorMessage "Failed to publish app to container"

        if ($publishSuccess -ne $false) {
            # Get updated app information after successful deployment
            $deployedAppInfo = Invoke-ScriptWithErrorHandling -ScriptBlock {
                $allApps = Get-BcContainerAppInfo -containerName $ContainerName -tenant default -tenantSpecificProperties

                # If we have app info from the file, find the matching deployed app
                if ($appInfo) {
                    $matchingApp = $allApps | Where-Object {
                        $_.Name -eq $appInfo.Name -and
                        $_.Publisher -eq $appInfo.Publisher -and
                        $_.Version -eq $appInfo.Version
                    } | Select-Object -First 1

                    if ($matchingApp) {
                        return $matchingApp
                    }
                }

                # Fallback: return the most recently published app
                return $allApps | Sort-Object -Property "PublishedAs" -Descending | Select-Object -First 1
            } -ErrorMessage "Failed to get deployed app information" -ContinueOnError

            $result.Success = $true
            $result.Message = "Successfully deployed $AppType app to container '$ContainerName'."
            $result.AppInfo = $deployedAppInfo

            Write-SuccessMessage $result.Message
        } else {
            $result.Success = $false
            $result.Message = "Failed to deploy $AppType app to container '$ContainerName'."

            Write-ErrorMessage $result.Message
        }
    }
    catch {
        # Handle any unexpected errors
        $result.Success = $false
        $result.Message = "An error occurred while deploying app: $_"

        Write-ErrorMessage $result.Message
    }

    return $result
}

#endregion

#region Main Script Execution

# Display script header
Write-SectionHeader "Deploy App" -ForegroundColor Cyan -DecorationType Box

# Execute the main function
$result = Invoke-DeployApp -Config $config -AppPath $AppPath -ContainerName $ContainerName -AppType $AppType

# Return the result
return $result

#endregion
