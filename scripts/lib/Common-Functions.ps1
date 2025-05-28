<#
.SYNOPSIS
    Common utility functions for Business Central TDD workflow.
.DESCRIPTION
    This script provides common utility functions used across multiple scripts in the Business Central TDD workflow:
    1. Message display functions (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, Write-WarningMessage)
    2. BcContainerHelper module import function
    3. Other common helper functions for the TDD workflow

    These functions are designed to be dot-sourced into other scripts to provide consistent functionality.
.EXAMPLE
    . .\scripts\Common-Functions.ps1
    # Imports all functions from this script into the current scope
.EXAMPLE
    . .\scripts\Common-Functions.ps1
    Write-InfoMessage "Initializing environment..."
    # Uses the imported function to display an info message
.NOTES
    This script is part of the Business Central TDD workflow.
#>

# Fail fast on any terminating / non-terminating error
$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
$InformationPreference = 'Continue'
$WarningPreference     = 'Continue'

# Define the user module path for BcContainerHelper
$userModulePath = Join-Path -Path ([Environment]::GetFolderPath('MyDocuments')) -ChildPath "PowerShell\Modules\BcContainerHelper"

#region Message Functions

function Write-InfoMessage {
    <#
    .SYNOPSIS
        Writes an information message to the host.
    .DESCRIPTION
        Writes a formatted information message to the host with a cyan color.
    .PARAMETER Message
        The message to display.
    .EXAMPLE
        Write-InfoMessage "Initializing environment..."
        # Displays: "INFO: Initializing environment..." in cyan
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message
    )

    Write-Host "INFO: $Message" -ForegroundColor Cyan
}

function Write-SuccessMessage {
    <#
    .SYNOPSIS
        Writes a success message to the host.
    .DESCRIPTION
        Writes a formatted success message to the host with a green color.
    .PARAMETER Message
        The message to display.
    .EXAMPLE
        Write-SuccessMessage "Container created successfully."
        # Displays: "SUCCESS: Container created successfully." in green
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message
    )

    Write-Host "SUCCESS: $Message" -ForegroundColor Green
}

function Write-ErrorMessage {
    <#
    .SYNOPSIS
        Writes an error message to the host.
    .DESCRIPTION
        Writes a formatted error message to the host with a red color.
    .PARAMETER Message
        The message to display.
    .PARAMETER Instructions
        Optional instructions on how to fix the error.
    .EXAMPLE
        Write-ErrorMessage "Failed to create container."
        # Displays: "ERROR: Failed to create container." in red
    .EXAMPLE
        Write-ErrorMessage "Failed to create container." "Check Docker is running and try again."
        # Displays: "ERROR: Failed to create container." in red
        # Displays: "INSTRUCTIONS: Check Docker is running and try again." in yellow
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false, Position = 1)]
        [string]$Instructions
    )

    Write-Host "ERROR: $Message" -ForegroundColor Red

    if (-not [string]::IsNullOrWhiteSpace($Instructions)) {
        Write-Host "INSTRUCTIONS: $Instructions" -ForegroundColor Yellow
    }
}

function Write-WarningMessage {
    <#
    .SYNOPSIS
        Writes a warning message to the host.
    .DESCRIPTION
        Writes a formatted warning message to the host with a yellow color.
    .PARAMETER Message
        The message to display.
    .EXAMPLE
        Write-WarningMessage "Container already exists."
        # Displays: "WARNING: Container already exists." in yellow
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Message
    )

    Write-Host "WARNING: $Message" -ForegroundColor Yellow
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a section header to the host.
    .DESCRIPTION
        Writes a formatted section header to the host with optional decoration.
    .PARAMETER Title
        The title of the section.
    .PARAMETER ForegroundColor
        The color to use for the title. Default is White.
    .PARAMETER DecorationType
        The type of decoration to use. Options are None, Underline, Box. Default is Underline.
    .EXAMPLE
        Write-SectionHeader "Environment Setup"
        # Displays a section header with the title "Environment Setup" underlined
    .EXAMPLE
        Write-SectionHeader "Environment Setup" -ForegroundColor Cyan -DecorationType Box
        # Displays a section header with the title "Environment Setup" in a box with cyan color
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Title,

        [Parameter(Mandatory = $false)]
        [System.ConsoleColor]$ForegroundColor = [System.ConsoleColor]::White,

        [Parameter(Mandatory = $false)]
        [ValidateSet("None", "Underline", "Box")]
        [string]$DecorationType = "Underline"
    )

    Write-Host ""

    switch ($DecorationType) {
        "None" {
            Write-Host $Title -ForegroundColor $ForegroundColor
        }
        "Underline" {
            Write-Host $Title -ForegroundColor $ForegroundColor
            Write-Host ("-" * $Title.Length) -ForegroundColor $ForegroundColor
        }
        "Box" {
            $border = "+" + ("-" * ($Title.Length + 2)) + "+"
            Write-Host $border -ForegroundColor $ForegroundColor
            Write-Host "| $Title |" -ForegroundColor $ForegroundColor
            Write-Host $border -ForegroundColor $ForegroundColor
        }
    }

    Write-Host ""
}

#endregion

#region BcContainerHelper Functions

function Import-BcContainerHelperModule {
    <#
    .SYNOPSIS
        Imports the BcContainerHelper module.
    .DESCRIPTION
        Attempts to import the BcContainerHelper module from various locations.
        If the module is not found, it provides instructions on how to install it.
    .PARAMETER Force
        If specified, forces the module to be reloaded even if it's already loaded.
    .PARAMETER SuppressVerbose
        If specified, suppresses verbose output during module import.
    .OUTPUTS
        System.Boolean. Returns $true if the module was imported successfully, $false otherwise.
    .EXAMPLE
        $moduleImported = Import-BcContainerHelperModule
        if ($moduleImported) {
            # Use BcContainerHelper cmdlets
        }
    .EXAMPLE
        Import-BcContainerHelperModule -Force
        # Forces the module to be reloaded
    .EXAMPLE
        Import-BcContainerHelperModule -SuppressVerbose
        # Imports the module with suppressed verbose output
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [switch]$Force,

        [Parameter(Mandatory = $false)]
        [switch]$SuppressVerbose
    )

    # Check if module is already imported and not forcing reload
    if (-not $Force -and (Get-Module -Name BcContainerHelper)) {
        Write-InfoMessage "BcContainerHelper module is already imported."
        return $true
    }

    # If forcing reload, remove the module first
    if ($Force -and (Get-Module -Name BcContainerHelper)) {
        Write-InfoMessage "Removing existing BcContainerHelper module for forced reload."
        Remove-Module -Name BcContainerHelper -Force -ErrorAction SilentlyContinue
    }

    # Save current preference values
    $originalVerbosePreference = $VerbosePreference
    $originalInformationPreference = $InformationPreference
    $originalWarningPreference = $WarningPreference

    # Suppress verbose output if requested
    if ($SuppressVerbose) {
        $VerbosePreference = 'SilentlyContinue'
        $InformationPreference = 'SilentlyContinue'
        $WarningPreference = 'SilentlyContinue'
    }

    $moduleImported = $false

    try {
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
                        if (-not $SuppressVerbose) {
                            Write-InfoMessage "Importing BcContainerHelper module from user module path: $modulePath"
                        }
                        Import-Module $modulePath -Force
                        $moduleImported = $true
                    }
                }
            }
            catch {
                if (-not $SuppressVerbose) {
                    Write-WarningMessage "Error importing BcContainerHelper from user module path: $_"
                }
            }
        }

        # Try to import from any available location if not already imported
        if (-not $moduleImported) {
            if (-not $SuppressVerbose) {
                Write-InfoMessage "Attempting to import BcContainerHelper module from PSModulePath..."
            }
            Import-Module BcContainerHelper -ErrorAction Stop
            $moduleImported = $true
        }

        if ($moduleImported) {
            Write-SuccessMessage "BcContainerHelper module imported successfully (Version: $((Get-Module -Name BcContainerHelper).Version))"
        }
    }
    catch {
        Write-ErrorMessage "BcContainerHelper module is not installed or cannot be imported." "Install the module by running: Install-Module BcContainerHelper -Force"
        $moduleImported = $false
    }
    finally {
        # Restore original preference values
        $VerbosePreference = $originalVerbosePreference
        $InformationPreference = $originalInformationPreference
        $WarningPreference = $originalWarningPreference
    }

    return $moduleImported
}

function Test-BcContainerHelperCommandAvailable {
    <#
    .SYNOPSIS
        Tests if a specific BcContainerHelper command is available.
    .DESCRIPTION
        Checks if the BcContainerHelper module is imported and if the specified command is available.
    .PARAMETER CommandName
        The name of the command to check.
    .OUTPUTS
        System.Boolean. Returns $true if the command is available, $false otherwise.
    .EXAMPLE
        if (Test-BcContainerHelperCommandAvailable -CommandName "New-BcContainer") {
            # Use New-BcContainer
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandName
    )

    # Check if BcContainerHelper is imported
    if (-not (Get-Module -Name BcContainerHelper)) {
        $imported = Import-BcContainerHelperModule
        if (-not $imported) {
            return $false
        }
    }

    # Check if the command exists
    $command = Get-Command -Name $CommandName -Module BcContainerHelper -ErrorAction SilentlyContinue
    return ($null -ne $command)
}

#endregion

#region Docker Functions

function Test-DockerRunning {
    <#
    .SYNOPSIS
        Tests if Docker is running.
    .DESCRIPTION
        Checks if Docker is running by executing a simple Docker command.
    .OUTPUTS
        System.Boolean. Returns $true if Docker is running, $false otherwise.
    .EXAMPLE
        if (Test-DockerRunning) {
            # Docker is running, proceed with container operations
        }
    #>
    [CmdletBinding()]
    param()

    try {
        docker info 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) {
            return $false
        }
        return $true
    }
    catch {
        return $false
    }
}

function Test-DockerContainerExists {
    <#
    .SYNOPSIS
        Tests if a Docker container exists.
    .DESCRIPTION
        Checks if a Docker container with the specified name exists.
    .PARAMETER ContainerName
        The name of the container to check.
    .OUTPUTS
        System.Boolean. Returns $true if the container exists, $false otherwise.
    .EXAMPLE
        if (Test-DockerContainerExists -ContainerName "bctest") {
            # Container exists, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )

    try {
        $containerList = docker ps -a --filter "name=$ContainerName" --format "{{.Names}}" 2>$null
        return ($null -ne $containerList -and $containerList.Trim() -eq $ContainerName)
    }
    catch {
        return $false
    }
}

function Test-DockerContainerRunning {
    <#
    .SYNOPSIS
        Tests if a Docker container is running.
    .DESCRIPTION
        Checks if a Docker container with the specified name exists and is running.
    .PARAMETER ContainerName
        The name of the container to check.
    .OUTPUTS
        System.Boolean. Returns $true if the container is running, $false otherwise.
    .EXAMPLE
        if (Test-DockerContainerRunning -ContainerName "bctest") {
            # Container is running, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )

    try {
        # First check if the container exists
        if (-not (Test-DockerContainerExists -ContainerName $ContainerName)) {
            return $false
        }

        # Check if the container is running
        $runningState = docker container inspect -f "{{.State.Running}}" $ContainerName 2>$null
        return ($null -ne $runningState -and $runningState.Trim() -eq "true")
    }
    catch {
        return $false
    }
}

function Get-DockerContainerInfo {
    <#
    .SYNOPSIS
        Gets information about a Docker container.
    .DESCRIPTION
        Retrieves detailed information about a Docker container with the specified name.
    .PARAMETER ContainerName
        The name of the container to get information about.
    .OUTPUTS
        PSCustomObject. Returns an object with container information.
    .EXAMPLE
        $containerInfo = Get-DockerContainerInfo -ContainerName "bctest"
        Write-Host "Container IP: $($containerInfo.IPAddress)"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )

    try {
        # Check if the container exists
        if (-not (Test-DockerContainerExists -ContainerName $ContainerName)) {
            Write-ErrorMessage "Container '$ContainerName' does not exist."
            return $null
        }

        # Get container information
        $containerJson = docker container inspect $ContainerName | ConvertFrom-Json

        # Extract relevant information
        $containerInfo = [PSCustomObject]@{
            Name = $ContainerName
            Id = $containerJson.Id
            Created = $containerJson.Created
            State = $containerJson.State.Status
            Running = $containerJson.State.Running
            IPAddress = $containerJson.NetworkSettings.Networks.nat.IPAddress
            Ports = $containerJson.NetworkSettings.Ports
            Image = $containerJson.Config.Image
            Labels = $containerJson.Config.Labels
        }

        return $containerInfo
    }
    catch {
        Write-ErrorMessage "Failed to get container information: $_"
        return $null
    }
}

#endregion

#region Path Functions

function Resolve-TDDPath {
    <#
    .SYNOPSIS
        Resolves a path relative to the TDD workflow.
    .DESCRIPTION
        Resolves a path relative to the TDD workflow, handling both absolute and relative paths.
        If the path is relative, it is resolved relative to the specified base path or the current directory.
    .PARAMETER Path
        The path to resolve.
    .PARAMETER BasePath
        The base path to use for resolving relative paths. Default is the current directory.
    .PARAMETER CreateIfNotExists
        If specified, creates the directory if it doesn't exist.
    .OUTPUTS
        System.String. Returns the resolved path.
    .EXAMPLE
        $resolvedPath = Resolve-TDDPath -Path ".\build\output"
        # Resolves the path relative to the current directory
    .EXAMPLE
        $resolvedPath = Resolve-TDDPath -Path ".\build\output" -BasePath "C:\MyProject"
        # Resolves the path relative to C:\MyProject
    .EXAMPLE
        $resolvedPath = Resolve-TDDPath -Path ".\build\output" -CreateIfNotExists
        # Resolves the path and creates the directory if it doesn't exist
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$Path,

        [Parameter(Mandatory = $false)]
        [string]$BasePath = (Get-Location).Path,

        [Parameter(Mandatory = $false)]
        [switch]$CreateIfNotExists
    )

    # Check if the path is already absolute
    if ([System.IO.Path]::IsPathRooted($Path)) {
        $resolvedPath = $Path
    }
    else {
        # Resolve the path relative to the base path
        $resolvedPath = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($BasePath, $Path))
    }

    # Create the directory if requested and it doesn't exist
    if ($CreateIfNotExists -and -not (Test-Path -Path $resolvedPath -PathType Container)) {
        try {
            New-Item -Path $resolvedPath -ItemType Directory -Force | Out-Null
            Write-InfoMessage "Created directory: $resolvedPath"
        }
        catch {
            Write-ErrorMessage "Failed to create directory: $resolvedPath" "Ensure you have permission to create directories in this location."
        }
    }

    return $resolvedPath
}

function Test-PathIsDirectory {
    <#
    .SYNOPSIS
        Tests if a path is a directory.
    .DESCRIPTION
        Checks if the specified path exists and is a directory.
    .PARAMETER Path
        The path to check.
    .OUTPUTS
        System.Boolean. Returns $true if the path is a directory, $false otherwise.
    .EXAMPLE
        if (Test-PathIsDirectory -Path "C:\MyProject\build") {
            # Path is a directory, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Test-Path -Path $Path -PathType Container)
}

function Test-PathIsFile {
    <#
    .SYNOPSIS
        Tests if a path is a file.
    .DESCRIPTION
        Checks if the specified path exists and is a file.
    .PARAMETER Path
        The path to check.
    .OUTPUTS
        System.Boolean. Returns $true if the path is a file, $false otherwise.
    .EXAMPLE
        if (Test-PathIsFile -Path "C:\MyProject\build\app.app") {
            # Path is a file, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return (Test-Path -Path $Path -PathType Leaf)
}

#endregion

#region Validation Functions

function Test-ValidCredential {
    <#
    .SYNOPSIS
        Tests if a credential is valid.
    .DESCRIPTION
        Checks if the specified credential is valid by ensuring it has a username and password.
    .PARAMETER Credential
        The credential to check.
    .OUTPUTS
        System.Boolean. Returns $true if the credential is valid, $false otherwise.
    .EXAMPLE
        $credential = Get-Credential
        if (Test-ValidCredential -Credential $credential) {
            # Credential is valid, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSCredential]$Credential
    )

    return ($null -ne $Credential -and
            -not [string]::IsNullOrWhiteSpace($Credential.UserName) -and
            $null -ne $Credential.Password -and
            $Credential.Password.Length -gt 0)
}

function Test-ValidContainerName {
    <#
    .SYNOPSIS
        Tests if a container name is valid.
    .DESCRIPTION
        Checks if the specified container name is valid according to Docker naming rules.
    .PARAMETER ContainerName
        The container name to check.
    .OUTPUTS
        System.Boolean. Returns $true if the container name is valid, $false otherwise.
    .EXAMPLE
        if (Test-ValidContainerName -ContainerName "my-container") {
            # Container name is valid, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ContainerName
    )

    # Docker container names must match the regex: [a-zA-Z0-9][a-zA-Z0-9_.-]+
    return ($ContainerName -match "^[a-zA-Z0-9][a-zA-Z0-9_.-]+$")
}

function Test-ValidAuthMethod {
    <#
    .SYNOPSIS
        Tests if an authentication method is valid.
    .DESCRIPTION
        Checks if the specified authentication method is valid for Business Central containers.
    .PARAMETER Auth
        The authentication method to check.
    .OUTPUTS
        System.Boolean. Returns $true if the authentication method is valid, $false otherwise.
    .EXAMPLE
        if (Test-ValidAuthMethod -Auth "NavUserPassword") {
            # Auth method is valid, proceed with operations
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Auth
    )

    $validAuthMethods = @("Windows", "UserPassword", "NavUserPassword")
    return ($Auth -in $validAuthMethods)
}

#endregion

#region Error Handling Functions

function Invoke-ScriptWithErrorHandling {
    <#
    .SYNOPSIS
        Invokes a script block with error handling.
    .DESCRIPTION
        Executes the specified script block with error handling, capturing and reporting any errors.
    .PARAMETER ScriptBlock
        The script block to execute.
    .PARAMETER ErrorMessage
        The error message to display if the script block fails.
    .PARAMETER ContinueOnError
        If specified, continues execution even if the script block fails.
    .OUTPUTS
        System.Boolean. Returns $true if the script block executed successfully, $false otherwise.
    .EXAMPLE
        $success = Invoke-ScriptWithErrorHandling -ScriptBlock { New-BcContainer -containerName "bctest" } -ErrorMessage "Failed to create container"
        if ($success) {
            # Container created successfully
        }
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = "An error occurred while executing the script block",

        [Parameter(Mandatory = $false)]
        [switch]$ContinueOnError
    )

    try {
        # Save the current error action preference
        $previousErrorActionPreference = $ErrorActionPreference

        # Set error action preference to Stop to ensure all errors are caught
        $ErrorActionPreference = 'Stop'

        # Execute the script block
        & $ScriptBlock

        # Restore the previous error action preference
        $ErrorActionPreference = $previousErrorActionPreference

        return $true
    }
    catch {
        # Restore the previous error action preference
        $ErrorActionPreference = $previousErrorActionPreference

        # Display the error message
        Write-ErrorMessage "$ErrorMessage`: $_"

        # Return false to indicate failure
        return $false
    }
}

#endregion

#region Project Root Functions

function Initialize-TDDProjectRoot {
    <#
    .SYNOPSIS
        Initializes and validates the TDD project root directory.
    .DESCRIPTION
        Centralizes project root detection logic for AL/Business Central TDD PowerShell scripts.
        Uses $PSScriptRoot for automatic script location detection, navigates to the parent
        directory (project root) from the scripts folder, validates that the target directory
        contains the expected app/test folders, and provides clear error messages if validation fails.

        This function integrates with the SourcePaths configuration from TDDConfig.psd1 and
        ensures robust operation regardless of script execution location.
    .PARAMETER ScriptRoot
        The root directory of the calling script. If not provided, attempts to determine
        automatically using $PSScriptRoot from the calling scope.
    .PARAMETER RequiredDirectories
        Array of directory names that must exist in the project root for validation to pass.
        Default is @('app', 'test', 'scripts').
    .PARAMETER SetLocation
        If specified, changes the current working directory to the project root.
        Default is $true.
    .PARAMETER RegisterCleanup
        If specified and SetLocation is $true, registers a cleanup action to restore
        the original location on script exit. Default is $true.
    .OUTPUTS
        PSCustomObject. Returns an object with the following properties:
        - ProjectRoot: The resolved project root path
        - ScriptDir: The scripts directory path
        - OriginalLocation: The original working directory (if SetLocation was used)
        - ValidationPassed: Boolean indicating if project structure validation passed
    .EXAMPLE
        $projectInfo = Initialize-TDDProjectRoot
        if ($projectInfo.ValidationPassed) {
            # Project root is valid and current directory is set to project root
            Write-Host "Project root: $($projectInfo.ProjectRoot)"
        }
    .EXAMPLE
        $projectInfo = Initialize-TDDProjectRoot -SetLocation:$false
        # Validates project structure but doesn't change current directory
    .EXAMPLE
        $projectInfo = Initialize-TDDProjectRoot -RequiredDirectories @('app', 'test', 'scripts', 'build')
        # Validates project structure with additional required directories
    .NOTES
        This function is designed to be called from TDD workflow scripts to centralize
        project root detection and validation logic. It integrates with the existing
        SourcePaths configuration in TDDConfig.psd1.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ScriptRoot,

        [Parameter(Mandatory = $false)]
        [string[]]$RequiredDirectories = @('app', 'test', 'scripts'),

        [Parameter(Mandatory = $false)]
        [bool]$SetLocation = $true,

        [Parameter(Mandatory = $false)]
        [bool]$RegisterCleanup = $true
    )

    # Initialize result object
    $result = [PSCustomObject]@{
        ProjectRoot = $null
        ScriptDir = $null
        OriginalLocation = $null
        ValidationPassed = $false
    }

    try {
        # Determine script directory using PSScriptRoot from calling scope if not provided
        if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
            # Get PSScriptRoot from the calling scope (one level up)
            $ScriptRoot = (Get-Variable -Name 'PSScriptRoot' -Scope 1 -ErrorAction SilentlyContinue).Value
        }

        if ([string]::IsNullOrWhiteSpace($ScriptRoot)) {
            Write-ErrorMessage "Unable to determine script directory. PSScriptRoot is not available." "This function must be called from a script file, not in an interactive session."
            return $result
        }

        $result.ScriptDir = $ScriptRoot

        # Calculate project root directory (parent of scripts directory)
        $projectRoot = Split-Path -Parent $ScriptRoot
        $result.ProjectRoot = $projectRoot

        # Validate project structure
        Write-Verbose "Validating project structure..."
        Write-Verbose "  Scripts directory: $ScriptRoot"
        Write-Verbose "  Project root: $projectRoot"

        $missingDirectories = @()

        foreach ($dir in $RequiredDirectories) {
            $dirPath = Join-Path -Path $projectRoot -ChildPath $dir
            if (-not (Test-Path -Path $dirPath -PathType Container)) {
                $missingDirectories += $dir
            }
        }

        if ($missingDirectories.Count -gt 0) {
            $errorMessage = @"
Project structure validation failed. The following required directories are missing:
$($missingDirectories -join ', ')

Expected project structure:
  $projectRoot/
  ├── app/          (Main app source directory)
  ├── test/         (Test app source directory)
  └── scripts/      (TDD workflow scripts)

Please ensure you are running this script from a valid AL/Business Central TDD project root.
Current project root: $projectRoot
"@
            Write-ErrorMessage $errorMessage
            return $result
        }

        # Project structure validation passed
        $result.ValidationPassed = $true

        # Change to project root directory for consistent relative path handling
        if ($SetLocation) {
            $result.OriginalLocation = Get-Location
            try {
                Set-Location -Path $projectRoot
                Write-Verbose "Working directory changed to project root: $projectRoot"

                # Register cleanup to restore original location on script exit
                if ($RegisterCleanup) {
                    $originalLocation = $result.OriginalLocation
                    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action {
                        try {
                            Set-Location -Path $originalLocation -ErrorAction SilentlyContinue
                        } catch {
                            # Silently ignore errors during cleanup
                        }
                    } | Out-Null
                }
            } catch {
                Write-ErrorMessage "Failed to change working directory to project root: $projectRoot" "Error: $($_.Exception.Message)"
                return $result
            }
        }

        Write-InfoMessage "TDD project root initialized successfully: $projectRoot"
        return $result

    } catch {
        Write-ErrorMessage "Failed to initialize TDD project root" "Error: $($_.Exception.Message)"
        return $result
    }
}

#endregion

# Note: Export-ModuleMember is only needed when this file is used as a module
# When dot-sourced, all functions are automatically available in the calling scope
if ($MyInvocation.Line -match 'Import-Module') {
    # Only export functions if being imported as a module
    Export-ModuleMember -Function * -Alias *
}