<#
.SYNOPSIS
    Verifies the environment for Business Central TDD workflow.
.DESCRIPTION
    This script checks if the required components for Business Central TDD workflow are installed and running:
    1. BcContainerHelper module is installed
    2. Docker is running
    3. The container specified in the configuration exists and is running
    If any requirements are not met, the script provides clear error messages and instructions on how to fix them.

    The script uses settings from the TDDConfig.psd1 file, including the container name and script behavior settings.
    If the configuration file cannot be loaded, default values are used.

    This script uses the centralized configuration management provided by Get-TDDConfiguration.ps1
    and common utility functions from Common-Functions.ps1.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "config\TDDConfig.psd1" relative to the scripts root directory.
.EXAMPLE
    .\Verify-Environment.ps1
    # Uses the default configuration file path
.EXAMPLE
    .\Verify-Environment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Uses a custom configuration file
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

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
    # We can't use Write-WarningMessage yet as Common-Functions.ps1 isn't loaded
    Write-Warning "Using hard-coded script directory: $scriptDir"
} else {
    $scriptDir = Split-Path -Parent $scriptPath
}

# Set default config path if not provided
if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $ConfigPath = Join-Path -Path $scriptDir -ChildPath "..\config\TDDConfig.psd1"
    # We can't use Write-InfoMessage yet as Common-Functions.ps1 isn't loaded
    Write-Verbose "Using default configuration path: $ConfigPath"
}

# Import Common-Functions.ps1
$commonFunctionsPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Common-Functions.ps1"
if (-not (Test-Path -Path $commonFunctionsPath)) {
    # We can't use Write-ErrorMessage yet as Common-Functions.ps1 isn't loaded
    Write-Error "Common-Functions.ps1 not found at path: $commonFunctionsPath. Make sure the script exists in the lib folder relative to Verify-Environment.ps1."
    exit 1
}
. $commonFunctionsPath

# Import the Get-TDDConfiguration script
$getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "..\lib\Get-TDDConfiguration.ps1"
if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-ErrorMessage "Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath" "Make sure the script exists in the lib folder relative to Verify-Environment.ps1."
    exit 1
}
. $getTDDConfigPath

# Main verification function
function Test-TDDEnvironment {
    <#
    .SYNOPSIS
        Verifies the TDD environment for Business Central.
    .DESCRIPTION
        Checks if the required components for Business Central TDD workflow are installed and running.
        Uses the centralized configuration management provided by Get-TDDConfiguration.ps1
        and common utility functions from Common-Functions.ps1.
    .OUTPUTS
        System.Boolean. Returns $true if all checks pass, $false otherwise.
    #>
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    $script:allChecksPass = $true

    # Load configuration using the centralized Get-TDDConfiguration function
    $params = @{}
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $params['ConfigPath'] = $ConfigPath
    }

    $config = Get-TDDConfiguration @params

    # If configuration is null, exit with error
    if ($null -eq $config) {
        Write-ErrorMessage "Failed to load configuration. Please check the configuration file and try again."
        return $false
    }

    # Get container name from configuration
    $containerName = $config.ContainerName

    # Apply script settings from configuration if available
    if ($config.ScriptSettings) {
        if ($config.ScriptSettings.ErrorActionPreference) {
            $ErrorActionPreference = $config.ScriptSettings.ErrorActionPreference
        }
        if ($config.ScriptSettings.VerbosePreference) {
            $VerbosePreference = $config.ScriptSettings.VerbosePreference
        }
        if ($config.ScriptSettings.InformationPreference) {
            $InformationPreference = $config.ScriptSettings.InformationPreference
        }
        if ($config.ScriptSettings.WarningPreference) {
            $WarningPreference = $config.ScriptSettings.WarningPreference
        }
    }

    Write-InfoMessage "Verifying environment for Business Central TDD workflow..."
    Write-InfoMessage "Using container name: $containerName (from configuration)"

    # Check 1: Verify BcContainerHelper module is installed and try to import it
    Write-InfoMessage "Checking if BcContainerHelper module is installed..."

    # Check if we should suppress verbose output from BcContainerHelper
    $suppressVerbose = $false
    if ($config.ScriptSettings -and $config.ScriptSettings.SuppressBcContainerHelperVerbose) {
        $suppressVerbose = $config.ScriptSettings.SuppressBcContainerHelperVerbose
    }

    $bcContainerHelperAvailable = Import-BcContainerHelperModule -SuppressVerbose:$suppressVerbose

    if (-not $bcContainerHelperAvailable) {
        Write-ErrorMessage "BcContainerHelper module is not installed or cannot be imported." "Install the module by running: Install-Module BcContainerHelper -Force"
        $script:allChecksPass = $false
    } else {
        $bcContainerHelper = Get-Module -Name BcContainerHelper
        Write-SuccessMessage "BcContainerHelper module is installed and imported (Version: $($bcContainerHelper.Version))"
    }

    # Check 1.1: Verify Expand-Archive cmdlet is available (needed for extracting alc.exe)
    Write-InfoMessage "Checking if Expand-Archive cmdlet is available..."

    $expandArchiveAvailable = $null -ne (Get-Command -Name Expand-Archive -ErrorAction SilentlyContinue)

    if (-not $expandArchiveAvailable) {
        Write-ErrorMessage "Expand-Archive cmdlet is not available." "This cmdlet is required for extracting alc.exe from VSIX files. Make sure you're using PowerShell 5.0 or later, or install the Microsoft.PowerShell.Archive module."
        $script:allChecksPass = $false
    } else {
        Write-SuccessMessage "Expand-Archive cmdlet is available"
    }

    # Check 2: Verify Docker is running
    Write-InfoMessage "Checking if Docker is running..."

    $dockerRunning = Test-DockerRunning

    if (-not $dockerRunning) {
        Write-ErrorMessage "Docker is not running or not installed." "Make sure Docker Desktop is installed and running. If not installed, download it from https://www.docker.com/products/docker-desktop"
        $script:allChecksPass = $false
    } else {
        Write-SuccessMessage "Docker is running"
    }

    # Check 3: Verify container exists and is running
    Write-InfoMessage "Checking if '$containerName' container exists and is running..."

    $containerExists = Test-DockerContainerExists -ContainerName $containerName
    $containerRunning = $false

    if ($containerExists) {
        $containerRunning = Test-DockerContainerRunning -ContainerName $containerName
    }

    if (-not $containerExists) {
        Write-WarningMessage "The '$containerName' container does not exist. Attempting to create it..."

        # Check if BcContainerHelper is available
        if ($bcContainerHelperAvailable) {
            # Call the Initialize-TDDEnvironment.ps1 script to create the container
            $initScriptPath = Join-Path -Path $scriptDir -ChildPath "..\Initialize-TDDEnvironment.ps1"

            if (Test-PathIsFile -Path $initScriptPath) {
                Write-InfoMessage "Calling Initialize-TDDEnvironment.ps1 to create the container..."

                # Call the script with parameters to prevent infinite recursion and pass the configuration
                $initParams = @{
                    SkipVerification = $true
                    ContainerName = $containerName
                }

                # Pass the config path if it was provided
                if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
                    $initParams['ConfigPath'] = $ConfigPath
                }

                $success = Invoke-ScriptWithErrorHandling -ScriptBlock {
                    & $initScriptPath @initParams
                } -ErrorMessage "Failed to execute Initialize-TDDEnvironment.ps1"

                if ($success) {
                    # Check if the container was created successfully
                    $containerExists = Test-DockerContainerExists -ContainerName $containerName
                    $containerRunning = $containerExists -and (Test-DockerContainerRunning -ContainerName $containerName)

                    if ($containerExists -and $containerRunning) {
                        Write-SuccessMessage "The '$containerName' container has been created and started successfully"
                    } else {
                        Write-ErrorMessage "Failed to create the '$containerName' container." "Check the output of Initialize-TDDEnvironment.ps1 for more information. You can also check the configuration in $ConfigPath."
                        $script:allChecksPass = $false
                    }
                } else {
                    $script:allChecksPass = $false
                }
            } else {
                Write-ErrorMessage "Initialize-TDDEnvironment.ps1 script not found at path: $initScriptPath" "Make sure the script exists in the scripts root folder relative to Verify-Environment.ps1."
                $script:allChecksPass = $false
            }
        } else {
            Write-ErrorMessage "BcContainerHelper module is required to create the container." "Install the module by running: Install-Module BcContainerHelper -Force"
            $script:allChecksPass = $false
        }
    } elseif (-not $containerRunning) {
        Write-WarningMessage "The '$containerName' container exists but is not running. Attempting to start it..."

        $success = Invoke-ScriptWithErrorHandling -ScriptBlock {
            # Try to use Start-BcContainer from BcContainerHelper module first
            if ($bcContainerHelperAvailable -and (Test-BcContainerHelperCommandAvailable -CommandName "Start-BcContainer")) {
                Write-InfoMessage "Using BcContainerHelper to start the container..."
                Start-BcContainer -containerName $containerName
            }
            # Fall back to docker CLI if BcContainerHelper is not available
            else {
                Write-InfoMessage "BcContainerHelper not available, using docker CLI instead..."
                docker start $containerName | Out-Null
            }
        } -ErrorMessage "Failed to start the '$containerName' container"

        if ($success) {
            # Verify the container is now running
            $containerRunning = Test-DockerContainerRunning -ContainerName $containerName

            if ($containerRunning) {
                Write-SuccessMessage "The '$containerName' container has been started successfully"
            } else {
                Write-ErrorMessage "Failed to start the '$containerName' container." "Check the Docker logs for more information: docker logs $containerName"
                $script:allChecksPass = $false
            }
        } else {
            $script:allChecksPass = $false
        }
    } else {
        Write-SuccessMessage "The '$containerName' container exists and is running"
    }

    # Final result
    if ($script:allChecksPass) {
        Write-SectionHeader "Environment Verification Result" -ForegroundColor Green
        Write-SuccessMessage "All environment checks passed! The environment is ready for Business Central TDD workflow."
        return $true
    } else {
        Write-SectionHeader "Environment Verification Result" -ForegroundColor Red
        Write-ErrorMessage "Environment verification failed. Please address the issues above before proceeding."
        return $false
    }
}

# Execute the verification
$success = Invoke-ScriptWithErrorHandling -ScriptBlock {
    $result = Test-TDDEnvironment -ConfigPath $ConfigPath

    # Set the exit code for the script
    if (-not $result) {
        # Exit with non-zero code to indicate failure when used in scripts
        exit 1
    } else {
        # Exit with zero code to indicate success
        exit 0
    }
} -ErrorMessage "An unexpected error occurred during environment verification"

if (-not $success) {
    exit 1
}