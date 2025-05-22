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

# Get the script path and set default config path if not provided
if (-not $PSBoundParameters.ContainsKey('ConfigPath')) {
    $scriptPath = $MyInvocation.MyCommand.Path
    $scriptDir = Split-Path -Parent $scriptPath
    $ConfigPath = Join-Path -Path $scriptDir -ChildPath "TDDConfig.psd1"
}

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
        Auth = "NavUserPassword"
        MemoryLimit = "8G"
        Accept_Eula = $true
        Accept_Outdated = $true
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
            Write-InfoMessage "Loading configuration from $ConfigPath..."
            $importedConfig = Import-PowerShellDataFile -Path $ConfigPath -ErrorAction Stop

            # Merge with default configuration (imported config takes precedence)
            $config = $defaultConfig.Clone()
            foreach ($key in $importedConfig.Keys) {
                $config[$key] = $importedConfig[$key]
            }

            Write-InfoMessage "Configuration loaded successfully."
            return $config
        } else {
            Write-InfoMessage "Configuration file not found at $ConfigPath. Using default values."
            return $defaultConfig
        }
    } catch {
        Write-InfoMessage "Error loading configuration from $ConfigPath`: $($_.Exception.Message)"
        Write-InfoMessage "Using default configuration values."
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

    # Load configuration
    $config = Import-TDDConfiguration -ConfigPath $ConfigPath

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

    Write-InfoMessage "Initializing environment for Business Central TDD workflow..."
    Write-InfoMessage "Using configuration from: $ConfigPath"
    $containerNameSource = if ($PSBoundParameters.ContainsKey('ContainerName')) { 'parameter' } else { 'configuration' }
    Write-InfoMessage "Container Name: $ContainerName (from $containerNameSource)"

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
    
    Write-InfoMessage "Container status: Exists=$containerExists, Running=$containerRunning"

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
            Write-ErrorMessage "SetupTestContainer.ps1 script not found at path: $setupScriptPath"
            return $false
        }
        
        Write-InfoMessage "Setup parameters for container creation:"
        foreach ($key in $setupParams.Keys) {
            if ($key -ne "Credential" -and $key -ne "Password") {  # Don't log sensitive information
                Write-InfoMessage "  $key = $($setupParams[$key])"
            } else {
                Write-InfoMessage "  $key = [SECURED]"
            }
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
    
    Write-SuccessMessage "Environment variables set up successfully."
    Write-InfoMessage "Environment variables set:"
    Write-InfoMessage "  BC_CONTAINER_NAME = $env:BC_CONTAINER_NAME"
    Write-InfoMessage "  BC_CONTAINER_IMAGE = $env:BC_CONTAINER_IMAGE"
    Write-InfoMessage "  BC_AUTH_METHOD = $env:BC_AUTH_METHOD"
    Write-InfoMessage "  BC_CONFIG_PATH = $env:BC_CONFIG_PATH"
    
    if ($env:BC_APP_SOURCE_PATH) { Write-InfoMessage "  BC_APP_SOURCE_PATH = $env:BC_APP_SOURCE_PATH" }
    if ($env:BC_TEST_SOURCE_PATH) { Write-InfoMessage "  BC_TEST_SOURCE_PATH = $env:BC_TEST_SOURCE_PATH" }
    if ($env:BC_BUILD_PATH) { Write-InfoMessage "  BC_BUILD_PATH = $env:BC_BUILD_PATH" }
    if ($env:BC_APP_OUTPUT_PATH) { Write-InfoMessage "  BC_APP_OUTPUT_PATH = $env:BC_APP_OUTPUT_PATH" }
    if ($env:BC_TEST_RESULTS_PATH) { Write-InfoMessage "  BC_TEST_RESULTS_PATH = $env:BC_TEST_RESULTS_PATH" }

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