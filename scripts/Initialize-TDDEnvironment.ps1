<#
.SYNOPSIS
    Initializes the environment for Business Central TDD workflow.
.DESCRIPTION
    This script sets up the environment for Business Central TDD workflow:
    1. Calls Verify-Environment.ps1 to ensure prerequisites are met
    2. If the container doesn't exist, creates it with appropriate settings
    3. If the container exists but isn't running, starts it
    4. Sets up any necessary environment variables for the TDD workflow
    
    The script uses settings from the TDDConfig.psd1 file, including container name,
    artifact URL, authentication method, and other container settings.
    If the configuration file cannot be loaded, default values are used.
    
    This script uses the centralized configuration management provided by Get-TDDConfiguration.ps1.
.PARAMETER ContainerName
    The name of the Business Central container to initialize. Default is from configuration or 'bctest'.
.PARAMETER ImageName
    The Business Central Docker image to use. If not provided, latest sandbox artifact will be used.
.PARAMETER Auth
    Authentication method for the container. Valid options are 'Windows', 'UserPassword', or 'NavUserPassword'. 
    Default is from configuration or 'NavUserPassword'.
.PARAMETER Credential
    Credentials for the container admin user. If not provided, default credentials (admin/P@ssw0rd) will be used. 
    These credentials are forwarded to the SetupTestContainer.ps1 script.
.PARAMETER MemoryLimit
    Memory limit for the container. Default is from configuration or '8G'.
.PARAMETER Accept_Eula
    Whether to accept the EULA. Default is from configuration or $true.
.PARAMETER Accept_Outdated
    Whether to accept outdated images. Default is from configuration or $true.
.PARAMETER ConfigPath
    Path to the configuration file. Default is "scripts\TDDConfig.psd1" in the same directory as this script.
.PARAMETER SkipVerification
    Whether to skip the environment verification step. Default is $false.
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1
    # Uses settings from the default configuration file
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1 -ContainerName "mytest" -Auth "Windows"
    # Overrides configuration settings with provided parameters
.EXAMPLE
    .\Initialize-TDDEnvironment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"
    # Uses a custom configuration file
.NOTES
    This script is part of the Business Central TDD workflow.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ContainerName,

    [Parameter(Mandatory = $false)]
    [string]$ImageName = "",

    [Parameter(Mandatory = $false)]
    [ValidateSet("Windows", "UserPassword", "NavUserPassword")]
    [string]$Auth,

    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,

    [Parameter(Mandatory = $false)]
    [string]$MemoryLimit,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Eula,

    [Parameter(Mandatory = $false)]
    [bool]$Accept_Outdated,
    
    [Parameter(Mandatory = $false)]
    [bool]$SkipVerification = $false,
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath
)

# Set default config path if not provided
if (-not $PSBoundParameters.ContainsKey('ConfigPath') -or [string]::IsNullOrWhiteSpace($ConfigPath)) {
    $scriptPath = $MyInvocation.MyCommand.Path
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        # Fallback if $MyInvocation.MyCommand.Path is empty
        $scriptPath = $PSCommandPath
    }
    
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        # Hard-coded fallback if both are empty
        $ConfigPath = "d:\repos\bctddflow\scripts\TDDConfig.psd1"
        Write-Host "WARNING: Using hard-coded configuration path: $ConfigPath" -ForegroundColor Yellow
    } else {
        $scriptDir = Split-Path -Parent $scriptPath
        $ConfigPath = Join-Path -Path $scriptDir -ChildPath "TDDConfig.psd1"
    }
    
    Write-Host "INFO: Using default configuration path: $ConfigPath" -ForegroundColor Cyan
}

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Define the user module path for BcContainerHelper
$userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\BcContainerHelper"

# Import the Get-TDDConfiguration script
$scriptPath = $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Fallback if $MyInvocation.MyCommand.Path is empty
    $scriptPath = $PSCommandPath
}

if ([string]::IsNullOrWhiteSpace($scriptPath)) {
    # Hard-coded fallback if both are empty
    $getTDDConfigPath = "d:\repos\bctddflow\scripts\Get-TDDConfiguration.ps1"
    Write-Host "WARNING: Using hard-coded path for Get-TDDConfiguration.ps1: $getTDDConfigPath" -ForegroundColor Yellow
} else {
    $scriptDir = Split-Path -Parent $scriptPath
    $getTDDConfigPath = Join-Path -Path $scriptDir -ChildPath "Get-TDDConfiguration.ps1"
}

if (-not (Test-Path -Path $getTDDConfigPath)) {
    Write-Host "ERROR: Get-TDDConfiguration.ps1 not found at path: $getTDDConfigPath" -ForegroundColor Red
    Write-Host "Make sure the script exists in the same folder as Initialize-TDDEnvironment.ps1." -ForegroundColor Yellow
    exit 1
}
. $getTDDConfigPath

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

# We'll use direct Write-Host calls instead of custom functions to avoid scope issues
# This matches the approach used in Get-TDDConfiguration.ps1

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
        Uses the centralized configuration management provided by Get-TDDConfiguration.ps1.
    .OUTPUTS
        System.Boolean. Returns $true if initialization is successful, $false otherwise.
    #>
    [CmdletBinding()]
    param()

    # Load configuration using the centralized Get-TDDConfiguration function
    $params = @{}
    if (-not [string]::IsNullOrWhiteSpace($ConfigPath)) {
        $params['ConfigPath'] = $ConfigPath
    }
    
    $config = Get-TDDConfiguration @params
    
    # If configuration is null, exit with error
    if ($null -eq $config) {
        Write-Host "ERROR: Failed to load configuration. Please check the configuration file and try again." -ForegroundColor Red
        return $false
    }

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

    # Apply configuration values if parameters are not explicitly provided
    if (-not $PSBoundParameters.ContainsKey('ContainerName')) {
        $script:ContainerName = $config.ContainerName
    }

    if (-not $PSBoundParameters.ContainsKey('Auth')) {
        $script:Auth = $config.Auth
    }

    if (-not $PSBoundParameters.ContainsKey('MemoryLimit')) {
        $script:MemoryLimit = $config.MemoryLimit
    }

    if (-not $PSBoundParameters.ContainsKey('Accept_Eula')) {
        $script:Accept_Eula = $config.Accept_Eula
    }

    if (-not $PSBoundParameters.ContainsKey('Accept_Outdated')) {
        $script:Accept_Outdated = $config.Accept_Outdated
    }

    Write-Host "INFO: Initializing environment for Business Central TDD workflow..." -ForegroundColor Cyan
    Write-Host "INFO: Using configuration from: $ConfigPath" -ForegroundColor Cyan
    $containerNameSource = if ($PSBoundParameters.ContainsKey('ContainerName')) { 'parameter' } else { 'configuration' }
    Write-Host "INFO: Container Name: $ContainerName (from $containerNameSource)" -ForegroundColor Cyan

    # Step 1: Verify environment prerequisites (unless skipped)
    if (-not $SkipVerification) {
        Write-Host "INFO: Verifying environment prerequisites..." -ForegroundColor Cyan
        $verifyScriptPath = Join-Path -Path $PSScriptRoot -ChildPath "Verify-Environment.ps1"
        
        if (-not (Test-Path -Path $verifyScriptPath)) {
            Write-Host "ERROR: Verify-Environment.ps1 script not found at path: $verifyScriptPath" -ForegroundColor Red
            return $false
        }

        try {
            # Call the verification script but don't exit if it fails
            # We'll handle the container creation/startup if needed
            # Use try-catch to properly handle exit codes from the script
            try {
                # Pass the configuration path to the verification script
                & $verifyScriptPath -ConfigPath $ConfigPath -ErrorAction Stop
                $verifyResult = $true  # If we get here, the script succeeded
            }
            catch {
                # The script exited with a non-zero exit code
                $verifyResult = $false
            }
            
            # Log the verification result
            if ($verifyResult) {
                Write-Host "INFO: Environment verification passed." -ForegroundColor Cyan
            }
            else {
                Write-Host "INFO: Environment verification failed. Will attempt to resolve issues." -ForegroundColor Cyan
            }
        }
        catch {
            Write-Host "ERROR: Error running Verify-Environment.ps1: $_" -ForegroundColor Red
            $verifyResult = $false
        }
    }
    else {
        Write-Host "INFO: Skipping environment verification as requested." -ForegroundColor Cyan
        $verifyResult = $true  # Assume verification passed when skipped
    }

    # Step 2: Check if BcContainerHelper module is available and try to import it
    $bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
    
    if (-not $bcContainerHelperAvailable) {
        Write-Host "ERROR: BcContainerHelper module is not installed or cannot be imported." -ForegroundColor Red
        Write-Host "Installing BcContainerHelper module..." -ForegroundColor Yellow
        try {
            Install-Module BcContainerHelper -Force
            $bcContainerHelperAvailable = Import-BcContainerHelperIfAvailable
            
            if ($bcContainerHelperAvailable) {
                Write-Host "SUCCESS: BcContainerHelper module installed and imported successfully." -ForegroundColor Green
            } else {
                throw "Failed to import BcContainerHelper module after installation."
            }
        }
        catch {
            Write-Host "ERROR: Failed to install BcContainerHelper module: $_" -ForegroundColor Red
            Write-Host "Please install the module manually by running: Install-Module BcContainerHelper -Force" -ForegroundColor Yellow
            Write-Host "Then restart your PowerShell session." -ForegroundColor Yellow
            return $false
        }
    } else {
        Write-Host "INFO: BcContainerHelper module is available and imported." -ForegroundColor Cyan
    }

    # Step 3: Check if Docker is running
    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "ERROR: Docker is not running." -ForegroundColor Red
            Write-Host "Please start Docker Desktop and try again." -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "ERROR: Docker is not installed or not accessible: $_" -ForegroundColor Red
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
        Write-Host "INFO: Container check failed: $_" -ForegroundColor Cyan
        $containerExists = $false
        $containerRunning = $false
    }
    
    Write-Host "INFO: Container status: Exists=$containerExists, Running=$containerRunning" -ForegroundColor Cyan

    # Handle container creation or startup
    if (-not $containerExists) {
        Write-Host "INFO: Container '$ContainerName' does not exist. Creating new container..." -ForegroundColor Cyan
        
        # Prepare parameters for SetupTestContainer.ps1
        $setupParams = @{
            ContainerName = $ContainerName
            Auth = $Auth
            MemoryLimit = $MemoryLimit
            Accept_Eula = $Accept_Eula
            Accept_Outdated = $Accept_Outdated
            ConfigPath = $ConfigPath  # Pass the configuration path to SetupTestContainer.ps1
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
            Write-Host "ERROR: SetupTestContainer.ps1 script not found at path: $setupScriptPath" -ForegroundColor Red
            return $false
        }
        
        Write-Host "INFO: Setup parameters for container creation:" -ForegroundColor Cyan
        foreach ($key in $setupParams.Keys) {
            if ($key -ne "Credential" -and $key -ne "Password") {  # Don't log sensitive information
                Write-Host "INFO:   $key = $($setupParams[$key])" -ForegroundColor Cyan
            } else {
                Write-Host "INFO:   $key = [SECURED]" -ForegroundColor Cyan
            }
        }

        try {
            Write-Host "INFO: Calling SetupTestContainer.ps1 to create the container..." -ForegroundColor Cyan
            
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
            
            Write-Host "SUCCESS: Container '$ContainerName' created successfully." -ForegroundColor Green
            $containerExists = $true
            $containerRunning = $true
            
            # Store container info for later use
            $script:containerDetails = $containerInfo
        }
        catch {
            Write-Host "ERROR: Failed to create container '$ContainerName': $_" -ForegroundColor Red
            Write-Host "Please check the parameters and try again." -ForegroundColor Yellow
            return $false
        }
    }
    elseif (-not $containerRunning) {
        Write-Host "INFO: Container '$ContainerName' exists but is not running. Starting container..." -ForegroundColor Cyan
        try {
            # Try to use Start-BcContainer from BcContainerHelper module first
            if ($bcContainerHelperAvailable -and (Get-Command Start-BcContainer -ErrorAction SilentlyContinue)) {
                Write-Host "INFO: Using BcContainerHelper to start the container..." -ForegroundColor Cyan
                Start-BcContainer -containerName $ContainerName
            }
            # Fall back to docker CLI if BcContainerHelper is not available
            else {
                Write-Host "INFO: BcContainerHelper not available, using docker CLI instead..." -ForegroundColor Cyan
                docker start $ContainerName | Out-Null
            }
            Write-Host "SUCCESS: Container '$ContainerName' started successfully." -ForegroundColor Green
            $containerRunning = $true
        }
        catch {
            Write-Host "ERROR: Failed to start container '$ContainerName': $_" -ForegroundColor Red
            return $false
        }
    }
    else {
        Write-Host "SUCCESS: Container '$ContainerName' is already running." -ForegroundColor Green
    }

    # Step 5: Set up environment variables
    Write-Host "INFO: Setting up environment variables for TDD workflow..." -ForegroundColor Cyan
    
    # Set environment variables for the current session
    $env:BC_CONTAINER_NAME = $ContainerName
    $env:BC_CONTAINER_IMAGE = $ImageName
    
    # Set additional environment variables from configuration
    $env:BC_AUTH_METHOD = $Auth
    $env:BC_CONFIG_PATH = $ConfigPath
    
    # Set path variables from configuration if available
    if ($config.SourcePaths) {
        if ($config.SourcePaths.App) {
            $env:BC_APP_SOURCE_PATH = $config.SourcePaths.App
        }
        if ($config.SourcePaths.Test) {
            $env:BC_TEST_SOURCE_PATH = $config.SourcePaths.Test
        }
    }
    
    if ($config.OutputPaths) {
        if ($config.OutputPaths.Build) {
            $env:BC_BUILD_PATH = $config.OutputPaths.Build
        }
        if ($config.OutputPaths.AppOutput) {
            $env:BC_APP_OUTPUT_PATH = $config.OutputPaths.AppOutput
        }
        if ($config.OutputPaths.TestResults) {
            $env:BC_TEST_RESULTS_PATH = $config.OutputPaths.TestResults
        }
    }
    
    Write-Host "SUCCESS: Environment variables set up successfully." -ForegroundColor Green
    Write-Host "INFO: Environment variables set:" -ForegroundColor Cyan
    Write-Host "INFO:   BC_CONTAINER_NAME = $env:BC_CONTAINER_NAME" -ForegroundColor Cyan
    Write-Host "INFO:   BC_CONTAINER_IMAGE = $env:BC_CONTAINER_IMAGE" -ForegroundColor Cyan
    Write-Host "INFO:   BC_AUTH_METHOD = $env:BC_AUTH_METHOD" -ForegroundColor Cyan
    Write-Host "INFO:   BC_CONFIG_PATH = $env:BC_CONFIG_PATH" -ForegroundColor Cyan
    
    if ($env:BC_APP_SOURCE_PATH) { Write-Host "INFO:   BC_APP_SOURCE_PATH = $env:BC_APP_SOURCE_PATH" -ForegroundColor Cyan }
    if ($env:BC_TEST_SOURCE_PATH) { Write-Host "INFO:   BC_TEST_SOURCE_PATH = $env:BC_TEST_SOURCE_PATH" -ForegroundColor Cyan }
    if ($env:BC_BUILD_PATH) { Write-Host "INFO:   BC_BUILD_PATH = $env:BC_BUILD_PATH" -ForegroundColor Cyan }
    if ($env:BC_APP_OUTPUT_PATH) { Write-Host "INFO:   BC_APP_OUTPUT_PATH = $env:BC_APP_OUTPUT_PATH" -ForegroundColor Cyan }
    if ($env:BC_TEST_RESULTS_PATH) { Write-Host "INFO:   BC_TEST_RESULTS_PATH = $env:BC_TEST_RESULTS_PATH" -ForegroundColor Cyan }

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
                Write-Host "  Configuration: $($script:containerDetails.ConfigPath) (Used: $($script:containerDetails.ConfigUsed))" -ForegroundColor White
                
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
                Write-Host "  Configuration: $ConfigPath (Used: $(Test-Path -Path $ConfigPath))" -ForegroundColor White
                Write-Host "  Auth: $Auth" -ForegroundColor White
                
                Write-Host "`nAccess Information:" -ForegroundColor Cyan
                Write-Host "  Web Client: http://$containerIP/BC" -ForegroundColor White
                Write-Host "  SOAP Services: http://$containerIP/BC/WS" -ForegroundColor White
                Write-Host "  OData Services: http://$containerIP/BC/ODataV4" -ForegroundColor White
            }
            
            Write-Host "`nEnvironment is ready for Business Central TDD workflow!" -ForegroundColor Green
            Write-Host "Configuration used: $ConfigPath" -ForegroundColor Green
        }
        catch {
            Write-Host "ERROR: Failed to retrieve container information: $_" -ForegroundColor Red
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