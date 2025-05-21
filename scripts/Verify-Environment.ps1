<#
.SYNOPSIS
    Verifies the environment for Business Central TDD workflow.
.DESCRIPTION
    This script checks if the required components for Business Central TDD workflow are installed and running:
    1. BcContainerHelper module is installed
    2. Docker is running
    3. The 'bctest' container exists and is running
    If any requirements are not met, the script provides clear error messages and instructions on how to fix them.
.EXAMPLE
    .\Verify-Environment.ps1
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"
$WarningPreference = "Continue"
$VerbosePreference = "Continue"

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
    $script:allChecksPass = $true

    Write-Host "Verifying environment for Business Central TDD workflow..." -ForegroundColor Cyan

    # Check 1: Verify BcContainerHelper module is installed
    Write-Host "Checking if BcContainerHelper module is installed..." -ForegroundColor Cyan
    $bcContainerHelper = Get-Module -Name BcContainerHelper -ListAvailable

    if (-not $bcContainerHelper) {
        Write-ErrorWithInstructions -ErrorMessage "BcContainerHelper module is not installed." -Instructions "Install the module by running: Install-Module BcContainerHelper -Force"
    } else {
        Write-Success -Message "BcContainerHelper module is installed (Version: $($bcContainerHelper.Version))"
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

    # Check 3: Verify 'bctest' container exists and is running
    Write-Host "Checking if 'bctest' container exists and is running..." -ForegroundColor Cyan
    try {
        $containerExists = $false
        $containerRunning = $false

        # Check if container exists
        docker container inspect bctest 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $containerExists = $true
            # Check if container is running using structured output
            $containerRunning = (docker container inspect -f "{{.State.Running}}" bctest 2>&1).Trim() -eq "true"
        }

        if (-not $containerExists) {
            Write-ErrorWithInstructions -ErrorMessage "The 'bctest' container does not exist." -Instructions "Create the container using BcContainerHelper. This will be handled by the Initialize-TDDEnvironment.ps1 script."
        } elseif (-not $containerRunning) {
            Write-ErrorWithInstructions -ErrorMessage "The 'bctest' container exists but is not running." -Instructions "Start the container using: docker start bctest"
        } else {
            Write-Success -Message "The 'bctest' container exists and is running"
        }
    } catch {
        Write-ErrorWithInstructions -ErrorMessage "Failed to check container status: $_" -Instructions "Make sure Docker is running and you have permission to execute Docker commands."
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
$result = Test-TDDEnvironment

# Set the exit code for the script
if (-not $result) {
    # Exit with non-zero code to indicate failure when used in scripts
    exit 1
} else {
    # Exit with zero code to indicate success
    exit 0
}