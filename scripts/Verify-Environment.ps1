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
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
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
    [string]$ConfigPath = (Join-Path -Path $PSScriptRoot -ChildPath "TDDConfig.psd1")
)

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Define the user module path for BcContainerHelper
$userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\BcContainerHelper"

# Function to import configuration from TDDConfig.psd1
function Import-TDDConfiguration {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    # Default configuration values
    $defaultConfig = @{
        ContainerName = "bctest"
        ScriptSettings = @{
            ErrorActionPreference = "Stop"
            VerbosePreference = "Continue"
            InformationPreference = "Continue"
            WarningPreference = "Continue"
        }
    }

    # Try to import configuration from file
    try {
        if (Test-Path -Path $ConfigPath) {
            Write-Host "Loading configuration from $ConfigPath..." -ForegroundColor Cyan
            $importedConfig = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop

            # Merge with default configuration (imported config takes precedence)
            $config = $defaultConfig.Clone()
            foreach ($key in $importedConfig.Keys) {
                $config[$key] = $importedConfig[$key]
            }

            Write-Host "Configuration loaded successfully." -ForegroundColor Green
            return $config
        } else {
            Write-Host "Configuration file not found at $ConfigPath. Using default values." -ForegroundColor Yellow
            return $defaultConfig
        }
    } catch {
        Write-Host "Error loading configuration from $ConfigPath`: $($_.Exception.Message)" -ForegroundColor Yellow
        Write-Host "Using default configuration values." -ForegroundColor Yellow
        return $defaultConfig
    }
}

# Function to check if BcContainerHelper is available and import it if possible
function Import-BcContainerHelperIfAvailable {
    [CmdletBinding()]
    param()

    # Check if module is already imported
    if (Get-Module -Name BcContainerHelper) {
        return $true
    }

    # Check if module is available in the user's module path
    if (Test-Path -Path $userModulePath) {
        try {
            # Find the latest version folder
            $latestVersion = Get-ChildItem -Path $userModulePath -Directory |
                             Sort-Object -Property Name -Descending |
                             Select-Object -First 1

            if ($latestVersion) {
                $modulePath = Join-Path -Path $latestVersion.FullName -ChildPath "BcContainerHelper.psd1"
                if (Test-Path -Path $modulePath) {
                    Import-Module $modulePath -Force
                    return $true
                }
            }
        }
        catch {
            Write-Host "Error importing BcContainerHelper from user module path: $_" -ForegroundColor Yellow
        }
    }

    # Try to import from any available location
    try {
        Import-Module BcContainerHelper -ErrorAction SilentlyContinue
        if (Get-Module -Name BcContainerHelper) {
            return $true
        }
    }
    catch {
        # Module not available
    }

    return $false
}

# Function to display error messages with instructions
function Write-ErrorWithInstructions {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage,

        [Parameter(Mandatory = $true)]
        [string]$Instructions
    )

    Write-Host "ERROR: $ErrorMessage" -ForegroundColor Red
    Write-Host "INSTRUCTIONS: $Instructions" -ForegroundColor Yellow
    # Don't return a value, just set the variable in the calling scope
    $script:allChecksPass = $false
}

# Function to display success messages
function Write-Success {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "SUCCESS: $Message" -ForegroundColor Green
    # No need to return anything
}

# Main verification function
function Test-TDDEnvironment {
    <#
    .SYNOPSIS
        Verifies the TDD environment for Business Central.
    .DESCRIPTION
        Checks if the required components for Business Central TDD workflow are installed and running.
    .OUTPUTS
        System.Boolean. Returns $true if all checks pass, $false otherwise.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )

    $script:allChecksPass = $true

    # Load configuration
    $config = Import-TDDConfiguration -ConfigPath $ConfigPath

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

    Write-Host "Verifying environment for Business Central TDD workflow..." -ForegroundColor Cyan
    Write-Host "Using container name: $containerName (from configuration)" -ForegroundColor Cyan

    # Check 1: Verify BcContainerHelper module is installed and try to import it
    Write-Host "Checking if BcContainerHelper module is installed..." -ForegroundColor Cyan

    $bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable

    if (-not $bcContainerHelperAvailable) {
        Write-ErrorWithInstructions -ErrorMessage "BcContainerHelper module is not installed or cannot be imported." -Instructions "Install the module by running: Install-Module BcContainerHelper -Force"
    } else {
        $bcContainerHelper = Get-Module -Name BcContainerHelper
        Write-Success -Message "BcContainerHelper module is installed and imported (Version: $($bcContainerHelper.Version))"
    }

    # Check 2: Verify Docker is running
    Write-Host "Checking if Docker is running..." -ForegroundColor Cyan
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            throw "Docker command failed with exit code $LASTEXITCODE"
        }
        Write-Success -Message "Docker is running"
    } catch {
        Write-ErrorWithInstructions -ErrorMessage "Docker is not running or not installed." -Instructions "Make sure Docker Desktop is installed and running. If not installed, download it from https://www.docker.com/products/docker-desktop"
    }

    # Check 3: Verify container exists and is running
    Write-Host "Checking if '$containerName' container exists and is running..." -ForegroundColor Cyan
    try {
        $containerExists = $false
        $containerRunning = $false

        # Check if container exists using a safer approach
        $containerList = docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null
        $containerExists = $null -ne $containerList -and $containerList.Trim() -eq $containerName

        if ($containerExists) {
            # Check if container is running using structured output
            $runningState = docker container inspect -f "{{.State.Running}}" $containerName 2>$null
            $containerRunning = $null -ne $runningState -and $runningState.Trim() -eq "true"
        }

        if (-not $containerExists) {
            Write-Host "The '$containerName' container does not exist. Attempting to create it..." -ForegroundColor Yellow

            # Check if BcContainerHelper is available
            if ($bcContainerHelperAvailable) {
                try {
                    # Call the Initialize-TDDEnvironment.ps1 script to create the container
                    $initScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Initialize-TDDEnvironment.ps1"

                    if (Test-Path -Path $initScriptPath) {
                        Write-Host "Calling Initialize-TDDEnvironment.ps1 to create the container..." -ForegroundColor Cyan
                        # Call the script with parameters to prevent infinite recursion and pass the configuration
                        $initParams = @{
                            SkipVerification = $true
                            ContainerName = $containerName
                        }

                        # Pass the config path if it was provided
                        if ($PSBoundParameters.ContainsKey('ConfigPath')) {
                            $initParams['ConfigPath'] = $ConfigPath
                        }

                        & $initScriptPath @initParams

                        # Check if the container was created successfully
                        $containerExists = $null -ne (docker ps -a --filter "name=$containerName" --format "{{.Names}}" 2>$null)
                        $containerRunning = $containerExists -and ((docker container inspect -f "{{.State.Running}}" $containerName 2>$null).Trim() -eq "true")

                        if ($containerExists -and $containerRunning) {
                            Write-Success -Message "The '$containerName' container has been created and started successfully"
                        } else {
                            Write-ErrorWithInstructions -ErrorMessage "Failed to create the '$containerName' container." -Instructions "Check the output of Initialize-TDDEnvironment.ps1 for more information. You can also check the configuration in $ConfigPath."
                        }
                    } else {
                        Write-ErrorWithInstructions -ErrorMessage "Initialize-TDDEnvironment.ps1 script not found at path: $initScriptPath" -Instructions "Make sure the script exists in the same folder as Verify-Environment.ps1."
                    }
                }
                catch {
                    Write-ErrorWithInstructions -ErrorMessage "Failed to create the '$containerName' container: $($_.Exception.Message)" -Instructions "Check the output of Initialize-TDDEnvironment.ps1 for more information. You can also check the configuration in $ConfigPath."
                }
            } else {
                Write-ErrorWithInstructions -ErrorMessage "BcContainerHelper module is required to create the container." -Instructions "Install the module by running: Install-Module BcContainerHelper -Force"
            }
        } elseif (-not $containerRunning) {
            Write-Host "The '$containerName' container exists but is not running. Attempting to start it..." -ForegroundColor Yellow

            try {
                # Try to use Start-BcContainer from BcContainerHelper module first
                if ($bcContainerHelperAvailable -and (Get-Command Start-BcContainer -ErrorAction SilentlyContinue)) {
                    Write-Host "Using BcContainerHelper to start the container..." -ForegroundColor Cyan
                    Start-BcContainer -containerName $containerName
                }
                # Fall back to docker CLI if BcContainerHelper is not available
                else {
                    Write-Host "BcContainerHelper not available, using docker CLI instead..." -ForegroundColor Cyan
                    docker start $containerName | Out-Null
                }

                # Verify the container is now running
                $containerRunning = (docker container inspect -f "{{.State.Running}}" $containerName 2>&1).Trim() -eq "true"

                if ($containerRunning) {
                    Write-Success -Message "The '$containerName' container has been started successfully"
                } else {
                    Write-ErrorWithInstructions -ErrorMessage "Failed to start the '$containerName' container." -Instructions "Check the Docker logs for more information: docker logs $containerName"
                }
            }
            catch {
                Write-ErrorWithInstructions -ErrorMessage "Failed to start the '$containerName' container: $($_.Exception.Message)" -Instructions "Check the Docker logs for more information: docker logs $containerName"
            }
        } else {
            Write-Success -Message "The '$containerName' container exists and is running"
        }
    } catch {
        Write-ErrorWithInstructions -ErrorMessage "Failed to check container status: $($_.Exception.Message)" -Instructions "Make sure Docker is running and you have permission to execute Docker commands."
    }

    # Final result
    if ($script:allChecksPass) {
        Write-Host "`nAll environment checks passed! The environment is ready for Business Central TDD workflow." -ForegroundColor Green
        return $true
    } else {
        Write-Host "`nEnvironment verification failed. Please address the issues above before proceeding." -ForegroundColor Red
        return $false
    }
}

# Execute the verification
$result = Test-TDDEnvironment -ConfigPath $ConfigPath

# Set the exit code for the script
if (-not $result) {
    # Exit with non-zero code to indicate failure when used in scripts
    exit 1
} else {
    # Exit with zero code to indicate success
    exit 0
}