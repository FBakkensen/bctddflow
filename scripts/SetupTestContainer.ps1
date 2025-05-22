<#
.SYNOPSIS
    Sets up a Business Central test container.
.DESCRIPTION
    This script creates a new Business Central container with test toolkit and performance toolkit.
.PARAMETER ContainerName
    The name of the Business Central container to create. Default is 'bctest'.
.PARAMETER ImageName
    The Business Central Docker image to use. If not provided, latest sandbox artifact will be used.
.PARAMETER Auth
    Authentication method for the container. Default is 'UserPassword'.
.PARAMETER Password
    Password for the admin user as a SecureString. If not provided, a default password will be used. Ignored if Credential parameter is provided.
.PARAMETER Credential
    PSCredential object for the container admin user. If provided, this takes precedence over the Password parameter.
.PARAMETER MemoryLimit
    Memory limit for the container. Default is '8G'.
.PARAMETER Accept_Eula
    Whether to accept the EULA. Default is $true.
.PARAMETER Accept_Outdated
    Whether to accept outdated images. Default is $true.
.EXAMPLE
    .\SetupTestContainer.ps1
.EXAMPLE
    .\SetupTestContainer.ps1 -ContainerName "mytest" -Auth "Windows"
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerName = "bctest",

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "UserPassword", "NavUserPassword")]
    [string]$Auth = "UserPassword",

    [Parameter(Mandatory = $false)]
    [System.Security.SecureString]$Password,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit = "8G",

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Eula = $true,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Outdated = $true
)

# Function to display info messages
function Write-InfoMessage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    Write-Host "INFO: $Message" -ForegroundColor Cyan
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

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'

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

# Ensure BcContainerHelper is available
$bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
if (-not $bcContainerHelperAvailable) {
    Write-Host "ERROR: BcContainerHelper module is not installed or cannot be imported." -ForegroundColor Red
    Write-Host "Please install the module by running: Install-Module BcContainerHelper -Force" -ForegroundColor Yellow
    exit 1
}

Write-InfoMessage "Setting up Business Central test container '$ContainerName'..."

# Create secure credential
if ($PSBoundParameters.ContainsKey('Credential')) {
    # Use the provided credential
    $credential = $Credential
    Write-InfoMessage "Using provided credentials for container admin user."
}
elseif ($PSBoundParameters.ContainsKey('Password')) {
    # Create credential from provided secure password
    $credential = New-Object pscredential 'admin', $Password
    Write-InfoMessage "Using default username with provided secure password."
}
else {
    # Create credential with default password
    $defaultSecurePassword = ConvertTo-SecureString -String "P@ssw0rd" -AsPlainText -Force
    $credential = New-Object pscredential 'admin', $defaultSecurePassword
    Write-InfoMessage "Using default credentials (admin/P@ssw0rd)."
}

# Always use artifact URL instead of image name to avoid warnings about outdated Docker images
Write-InfoMessage "Getting latest sandbox artifact..."
$artifactUrl = Get-BcArtifactUrl -type 'Sandbox' -country 'w1' -select 'Latest'

try {
    # Create the container following the exact pattern provided
    Write-InfoMessage "Creating container using artifact URL..."
    
    New-BcContainer `
        -accept_eula `
        -containerName $ContainerName `
        -credential $credential `
        -auth $Auth `
        -artifactUrl $artifactUrl `
        -includeTestToolkit `
        -includePerformanceToolkit `
        -assignPremiumPlan `
        -dns '8.8.8.8' `
        -updateHosts
    
    # Setup test users
    Write-InfoMessage "Setting up test users..."
    Setup-BcContainerTestUsers -containerName $ContainerName -Password $credential.Password -credential $credential
    
    Write-SuccessMessage "Container '$ContainerName' setup completed successfully."
}
catch {
    Write-Host "ERROR: Failed to create or setup container: $_" -ForegroundColor Red
    # Exit with non-zero code to indicate failure
    exit 1
}

# Return container information
$containerInfo = docker container inspect $ContainerName | ConvertFrom-Json
$containerIP = $containerInfo.NetworkSettings.Networks.nat.IPAddress

# Return object with container details as a strongly-typed PSCustomObject for better tab-completion and type safety
$result = [PSCustomObject]@{
    ContainerName    = $ContainerName
    IPAddress        = $containerIP
    Auth             = $Auth
    WebClientUrl     = "http://$containerIP/BC"
    SOAPServicesUrl  = "http://$containerIP/BC/WS"
    ODataServicesUrl = "http://$containerIP/BC/ODataV4"
}

# Return the result and exit with success code
return $result