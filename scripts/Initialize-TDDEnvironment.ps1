<#
.SYNOPSIS
    Initializes the environment for Business Central TDD workflow.
.DESCRIPTION
    This script sets up the environment for Business Central TDD workflow:
    1. Calls Verify-Environment.ps1 to ensure prerequisites are met
    2. If the 'bctest' container doesn't exist, creates it with appropriate settings
    3. If the container exists but isn't running, starts it
    4. Sets up any necessary environment variables for the TDD workflow
.PARAMETER ContainerName
    The name of the Business Central container to initialize. Default is 'bctest'.
.PARAMETER ImageName
    The Business Central Docker image to use. Default is 'mcr.microsoft.com/businesscentral:latest'.
# License file parameter removed as it's no longer needed for BC container creation
.PARAMETER Auth
    Authentication method for the container. Valid options are 'Windows', 'UserPassword', or 'NavUserPassword'. Default is 'NavUserPassword'.
.PARAMETER Credential
    Credentials for the container admin user. If not provided, default credentials (admin/P@ssw0rd) will be used. These credentials are forwarded to the SetupTestContainer.ps1 script.
.PARAMETER MemoryLimit
    Memory limit for the container. Default is '8G'.
.PARAMETER Accept_Eula
    Whether to accept the EULA. Default is $true.
.PARAMETER Accept_Outdated
    Whether to accept outdated images. Default is $true.
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1 -ContainerName "mytest" -ImageName "mcr.microsoft.com/businesscentral:us"
# License file example removed as it's no longer needed for BC container creation
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "bctest",

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "",

    # License file parameter removed as it's no longer needed for BC container creation

    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "UserPassword", "NavUserPassword")]
    [string]$Auth = "NavUserPassword",

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit = "8G",

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Eula = $true,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Outdated = $true,
    
    [Parameter(Mandatory = $false)]
    [bool]$SkipVerification = $false
)

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Define the user module path for BcContainerHelper
$userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\BcContainerHelper"

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

# Function to display error messages
function Write-ErrorMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ErrorMessage
    )

    Write-Host "ERROR: $ErrorMessage" -ForegroundColor Red
}

# Function to display success messages
function Write-SuccessMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

# Function to display info messages
function Write-InfoMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

# Main function to initialize the TDD environment
function Initialize-BCTDDEnvironment {
    <#
    .SYNOPSIS
        Initializes the Business Central TDD environment.
    .DESCRIPTION
        Sets up the Business Central container for TDD workflow.
    .OUTPUTS
        System.Boolean. Returns $true if initialization is successful, $false otherwise.
    #>
    [CmdletBinding()]
    param()

    Write-InfoMessage "Initializing environment for Business Central TDD workflow..."

    # Step 1: Verify environment prerequisites (unless skipped)
    if (-not $SkipVerification) {
        Write-InfoMessage "Verifying environment prerequisites..."
        $verifyScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Verify-Environment.ps1"
        
        if (-not (Test-Path -Path $verifyScriptPath)) {
            Write-ErrorMessage "Verify-Environment.ps1 script not found at path: $verifyScriptPath"
            return $false
        }

        try {
            # Call the verification script but don't exit if it fails
            # We'll handle the container creation/startup if needed
            # Use try-catch to properly handle exit codes from the script
            try {
                & $verifyScriptPath -ErrorAction Stop
                $verifyResult = $true  # If we get here, the script succeeded
            }
            catch {
                # The script exited with a non-zero exit code
                $verifyResult = $false
            }
            
            # Log the verification result
            if ($verifyResult) {
                Write-InfoMessage "Environment verification passed."
            }
            else {
                Write-InfoMessage "Environment verification failed. Will attempt to resolve issues."
            }
        }
        catch {
            Write-ErrorMessage "Error running Verify-Environment.ps1: $_"
            $verifyResult = $false
        }
    }
    else {
        Write-InfoMessage "Skipping environment verification as requested."
        $verifyResult = $true  # Assume verification passed when skipped
    }

    # Step 2: Check if BcContainerHelper module is available and try to import it
    $bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
    
    if (-not $bcContainerHelperAvailable) {
        Write-ErrorMessage "BcContainerHelper module is not installed or cannot be imported."
        Write-Host "Installing BcContainerHelper module..." -ForegroundColor Yellow
        try {
            Install-Module BcContainerHelper -Force
            $bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
            
            if ($bcContainerHelperAvailable) {
                Write-SuccessMessage "BcContainerHelper module installed and imported successfully."
            } else {
                throw "Failed to import BcContainerHelper module after installation."
            }
        }
        catch {
            Write-ErrorMessage "Failed to install BcContainerHelper module: $_"
            Write-Host "Please install the module manually by running: Install-Module BcContainerHelper -Force" -ForegroundColor Yellow
            Write-Host "Then restart your PowerShell session." -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-InfoMessage "BcContainerHelper module is available and imported."
    }

    # Step 3: Check if Docker is running
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-ErrorMessage "Docker is not running."
            Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-ErrorMessage "Docker is not installed or not accessible: $_"
        Write-Host "Please install Docker Desktop from https://www.docker.com/products/docker-desktop" -ForegroundColor Yellow
        return $false
    }

    # Step 4: Check if container exists and create/start as needed
    $containerExists = $false
    $containerRunning = $false

    try {
        # Check if container exists
        docker container inspect $ContainerName 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $containerExists = $true
            # Check if container is running using structured output
            $containerRunning = (docker container inspect -f "{{.State.Running}}" $ContainerName 2>&1).Trim() -eq "true"
        }
    }
    catch {
        Write-InfoMessage "Container check failed: $_"
        $containerExists = $false
        $containerRunning = $false
    }

    # Handle container creation or startup
    if (-not $containerExists) {
        Write-InfoMessage "Container '$ContainerName' does not exist. Creating new container..."
        
        # Prepare parameters for SetupTestContainer.ps1
        $setupParams = @{
            ContainerName = $ContainerName
            Auth = $Auth
            MemoryLimit = $MemoryLimit
            Accept_Eula = $Accept_Eula
            Accept_Outdated = $Accept_Outdated
        }

        # Add ImageName if provided
        if (-not [string]::IsNullOrEmpty($ImageName)) {
            $setupParams.Add("ImageName", $ImageName)
        }
        
        # Forward credentials if provided
        if ($PSBoundParameters.ContainsKey('Credential')) {
            # Just pass the credential object directly
            $setupParams['Credential'] = $Credential
        }

        # Get the path to SetupTestContainer.ps1
        $setupScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "SetupTestContainer.ps1"
        
        if (-not (Test-Path -Path $setupScriptPath)) {
            Write-ErrorMessage "SetupTestContainer.ps1 script not found at path: $setupScriptPath"
            return $false
        }

        try {
            Write-InfoMessage "Calling SetupTestContainer.ps1 to create the container..."
            
            # Call the setup script and capture its output
            # Use try-catch to properly handle exit codes from the script
            try {
                $containerInfo = & $setupScriptPath @setupParams -ErrorAction Stop
                $setupSuccess = $true
            }
            catch {
                $setupSuccess = $false
                throw "SetupTestContainer.ps1 failed: $_"
            }
            
            if (-not $setupSuccess) {
                throw "SetupTestContainer.ps1 signalled failure."
            }
            
            Write-SuccessMessage "Container '$ContainerName' created successfully."
            $containerExists = $true
            $containerRunning = $true
            
            # Store container info for later use
            $script:containerDetails = $containerInfo
        }
        catch {
            Write-ErrorMessage "Failed to create container '$ContainerName': $_"
            Write-Host "Please check the parameters and try again." -ForegroundColor Yellow
            return $false
        }
    }
    elseif (-not $containerRunning) {
        Write-InfoMessage "Container '$ContainerName' exists but is not running. Starting container..."
        try {
            # Try to use Start-BcContainer from BcContainerHelper module first
            if ($bcContainerHelperAvailable -and (Get-Command Start-BcContainer -ErrorAction SilentlyContinue)) {
                Write-InfoMessage "Using BcContainerHelper to start the container..."
                Start-BcContainer -containerName $ContainerName
            }
            # Fall back to docker CLI if BcContainerHelper is not available
            else {
                Write-InfoMessage "BcContainerHelper not available, using docker CLI instead..."
                docker start $ContainerName | Out-Null
            }
            Write-SuccessMessage "Container '$ContainerName' started successfully."
            $containerRunning = $true
        }
        catch {
            Write-ErrorMessage "Failed to start container '$ContainerName': $_"
            return $false
        }
    }
    else {
        Write-SuccessMessage "Container '$ContainerName' is already running."
    }

    # Step 5: Set up environment variables
    Write-InfoMessage "Setting up environment variables for TDD workflow..."
    
    # Set environment variables for the current session
    $env:BC_CONTAINER_NAME = $ContainerName
    $env:BC_CONTAINER_IMAGE = $ImageName
    
    Write-SuccessMessage "Environment variables set up successfully."

    # Step 6: Display container information
    if ($containerRunning) {
        try {
            # If container was just created, use the details returned by SetupTestContainer.ps1
            if ($script:containerDetails) {
                $containerIP = $script:containerDetails.IPAddress
                
                Write-Host "`nContainer Information:" -ForegroundColor Cyan
                Write-Host "  Name: $($script:containerDetails.ContainerName)" -ForegroundColor White
                Write-Host "  IP Address: $containerIP" -ForegroundColor White
                Write-Host "  Auth: $($script:containerDetails.Auth)" -ForegroundColor White
                Write-Host "  Status: Running" -ForegroundColor Green
                
                Write-Host "`nAccess Information:" -ForegroundColor Cyan
                Write-Host "  Web Client: $($script:containerDetails.WebClientUrl)" -ForegroundColor White
                Write-Host "  SOAP Services: $($script:containerDetails.SOAPServicesUrl)" -ForegroundColor White
                Write-Host "  OData Services: $($script:containerDetails.ODataServicesUrl)" -ForegroundColor White
            }
            # Otherwise, get container information from Docker
            else {
                $containerInfo = docker container inspect $ContainerName | ConvertFrom-Json
                $containerIP = $containerInfo.NetworkSettings.Networks.nat.IPAddress
                
                Write-Host "`nContainer Information:" -ForegroundColor Cyan
                Write-Host "  Name: $ContainerName" -ForegroundColor White
                Write-Host "  Image: $ImageName" -ForegroundColor White
                Write-Host "  IP Address: $containerIP" -ForegroundColor White
                Write-Host "  Status: Running" -ForegroundColor Green
                
                Write-Host "`nAccess Information:" -ForegroundColor Cyan
                Write-Host "  Web Client: http://$containerIP/BC" -ForegroundColor White
                Write-Host "  SOAP Services: http://$containerIP/BC/WS" -ForegroundColor White
                Write-Host "  OData Services: http://$containerIP/BC/ODataV4" -ForegroundColor White
            }
            
            Write-Host "`nEnvironment is ready for Business Central TDD workflow!" -ForegroundColor Green
        }
        catch {
            Write-ErrorMessage "Failed to retrieve container information: $_"
        }
    }

    return $true
}

# Execute the initialization
$result = Initialize-BCTDDEnvironment

# Set the exit code for the script
if (-not $result) {
    # Exit with non-zero code to indicate failure when used in scripts
    exit 1
} else {
    # Exit with zero code to indicate success
    exit 0
}