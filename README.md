# AL-Go Per Tenant Extension Template

## Overview

This is a template repository for managing AppSource Apps for Business Central using the AL-Go framework. Key features include:

- **GitHub Actions Workflows** for CI/CD, pull requests, and app creation
- **PowerPlatform Integration** with workflows for building, deploying, and syncing changes
- **Development Environment Setup** with scripts for both cloud and local environments
- **App Management** tools for creating new apps, test apps, and adding existing apps
- **Build Pipeline** using reusable workflows like `_BuildALGoProject.yaml`

The repository follows Microsoft's AL-Go framework (v7.1) for Business Central app development, providing automation for building, testing, and deploying Business Central extensions. It's designed as a template for per-tenant extensions with sample code included.

## Getting Started

To get started with this template repository, follow these steps:

1. **Clone the Repository**: Clone this repository to your local machine using `git clone https://github.com/your-repo.git`.
2. **Customize Settings**: Modify the AL-Go settings in the repository to match your project's requirements.
3. **Set Up Workflows**: Configure the GitHub Actions workflows according to your needs.
4. **Start Developing**: Begin developing your Business Central extensions using the provided templates and workflows.

## PowerShell Scripts Documentation

This section provides comprehensive documentation for all PowerShell scripts in the `scripts/` folder, which are used to manage the Business Central TDD workflow.

### Common Features Across Scripts

All scripts in the `scripts/` folder share these common features:

- **Centralized Configuration**: Use `Get-TDDConfiguration.ps1` to load settings from `TDDConfig.psd1`
- **Common Utility Functions**: Import functions from `Common-Functions.ps1` for consistent behavior
- **Error Handling**: Use structured error handling with clear error messages and instructions
- **Verbose Logging**: Provide detailed information about operations being performed
- **Exit Codes**: Return meaningful exit codes for use in automated workflows
- **PSScriptAnalyzer Compliance**: Follow PowerShell best practices and approved verbs

### Script Documentation

#### Common-Functions.ps1

**Purpose**: Provides common utility functions used across multiple scripts in the Business Central TDD workflow.

**Dependencies**:
- None (this is a dependency for other scripts)

**Functions**:
- **Message Functions**: `Write-InfoMessage`, `Write-SuccessMessage`, `Write-ErrorMessage`, `Write-WarningMessage`, `Write-SectionHeader`
- **BcContainerHelper Functions**: `Import-BcContainerHelperModule`, `Test-BcContainerHelperCommandAvailable`
- **Docker Functions**: `Test-DockerRunning`, `Test-DockerContainerExists`, `Test-DockerContainerRunning`, `Get-DockerContainerInfo`
- **Path Functions**: `Resolve-TDDPath`, `Test-PathIsDirectory`, `Test-PathIsFile`
- **Validation Functions**: `Test-ValidCredential`, `Test-ValidContainerName`, `Test-ValidAuthMethod`
- **Error Handling Functions**: `Invoke-ScriptWithErrorHandling`

**Usage Example**:
```powershell
# Import common functions
. .\scripts\Common-Functions.ps1

# Use imported functions
Write-InfoMessage "Initializing environment..."
$bcContainerHelperAvailable = Import-BcContainerHelperModule
if ($bcContainerHelperAvailable) {
    Write-SuccessMessage "BcContainerHelper module imported successfully"
}
```

#### Get-TDDConfiguration.ps1

**Purpose**: Loads and validates the TDD configuration for Business Central from the `TDDConfig.psd1` file.

**Parameters**:
- `ConfigPath`: Path to the configuration file (default: "scripts\TDDConfig.psd1")
- `OverrideSettings`: Hashtable of settings to override from the configuration file
- `RequiredSettings`: Array of setting keys that must be present in the final configuration
- `ValidateOnly`: If specified, only validates the configuration without returning it

**Returns**:
- Hashtable containing the complete configuration
- Boolean if ValidateOnly is specified (true if valid, false otherwise)

**Dependencies**:
- `Common-Functions.ps1`

**Usage Examples**:
```powershell
# Load default configuration
$config = .\scripts\Get-TDDConfiguration.ps1

# Load with custom path
$config = .\scripts\Get-TDDConfiguration.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"

# Override specific settings
$config = .\scripts\Get-TDDConfiguration.ps1 -OverrideSettings @{
    ContainerName = "mycontainer"
    Auth = "Windows"
}

# Validate required settings
$config = .\scripts\Get-TDDConfiguration.ps1 -RequiredSettings @(
    "ContainerName", "Auth", "MemoryLimit"
)

# Validate only
$isValid = .\scripts\Get-TDDConfiguration.ps1 -ValidateOnly
```

#### Initialize-TDDEnvironment.ps1

**Purpose**: Initializes the environment for Business Central TDD workflow by ensuring prerequisites are met and the container is created and running.

**Parameters**:
- `ContainerName`: Name of the Business Central container (default: from config or 'bctest')
- `ImageName`: Business Central Docker image to use (default: latest sandbox artifact)
- `Auth`: Authentication method for the container (default: from config or 'NavUserPassword')
- `Credential`: Credentials for the container admin user
- `MemoryLimit`: Memory limit for the container (default: from config or '8G')
- `Accept_Eula`: Whether to accept the EULA (default: from config or $true)
- `Accept_Outdated`: Whether to accept outdated images (default: from config or $true)
- `ConfigPath`: Path to the configuration file
- `SkipVerification`: Whether to skip the environment verification step

**Returns**: Boolean indicating success or failure

**Dependencies**:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`
- `Verify-Environment.ps1`
- `SetupTestContainer.ps1`
- BcContainerHelper module

**Usage Examples**:
```powershell
# Use default settings
.\scripts\Initialize-TDDEnvironment.ps1

# Override container name and auth method
.\scripts\Initialize-TDDEnvironment.ps1 -ContainerName "mytest" -Auth "Windows"

# Use custom configuration file
.\scripts\Initialize-TDDEnvironment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"

# Skip verification step
.\scripts\Initialize-TDDEnvironment.ps1 -SkipVerification $true
```

#### Script-Template.ps1

**Purpose**: Template for creating new PowerShell scripts for the Business Central TDD workflow with consistent structure and error handling.

**Parameters**:
- `ConfigPath`: Path to the configuration file
- `Parameter1`: Example parameter 1
- `Parameter2`: Example parameter 2

**Returns**: PSCustomObject with operation results (Success, Message, Data, Timestamp)

**Dependencies**:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`

**Usage Example**:
```powershell
# Create a new script based on the template
Copy-Item .\scripts\Script-Template.ps1 .\scripts\My-NewScript.ps1

# Edit the new script to implement your functionality
# Then run it with parameters
.\scripts\My-NewScript.ps1 -Parameter1 "Value1" -Parameter2 "Value2"
```

#### SetupTestContainer.ps1

**Purpose**: Creates a new Business Central container with test toolkit and performance toolkit.

**Parameters**:
- `ContainerName`: Name of the Business Central container (default: from config or 'bctest')
- `ImageName`: Business Central Docker image to use
- `Auth`: Authentication method for the container (default: from config or 'NavUserPassword')
- `Password`: Password for the admin user as a SecureString
- `Credential`: PSCredential object for the container admin user
- `MemoryLimit`: Memory limit for the container (default: from config or '8G')
- `Accept_Eula`: Whether to accept the EULA (default: from config or $true)
- `Accept_Outdated`: Whether to accept outdated images (default: from config or $true)
- `ConfigPath`: Path to the configuration file
- `Country`: Country version for the Business Central container (default: from config or 'w1')
- `IncludeTestToolkit`: Whether to include the test toolkit (default: from config or $true)
- `IncludePerformanceToolkit`: Whether to include the performance toolkit (default: from config or $true)
- `AssignPremiumPlan`: Whether to assign the premium plan (default: from config or $true)

**Returns**: PSCustomObject with container details (ContainerName, IPAddress, Auth, WebClientUrl, etc.)

**Dependencies**:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`
- BcContainerHelper module

**Usage Examples**:
```powershell
# Create container with default settings
.\scripts\SetupTestContainer.ps1

# Create container with custom settings
.\scripts\SetupTestContainer.ps1 -ContainerName "mytest" -Auth "Windows" -Country "us"

# Create container with custom credentials
$securePassword = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("admin", $securePassword)
.\scripts\SetupTestContainer.ps1 -Credential $credential
```

#### TDDConfig.psd1

**Purpose**: Configuration file for the Business Central TDD workflow containing settings for container creation, compilation, publishing, testing, and script behavior.

**Key Settings**:
- **Environment Settings**: ContainerName, ArtifactUrl, Auth, Country, MemoryLimit, etc.
- **Path Settings**: SourcePaths, OutputPaths
- **Compilation Settings**: CodeAnalysis, TreatWarningsAsErrors, EnableCodeCop, etc.
- **Publishing Settings**: Scope, SyncMode, PublishingTimeout, etc.
- **Test Settings**: DefaultTimeout, FailFast, TestRunnerCodeunitId, etc.
- **Watch Mode Settings**: Enabled, Interval, AutoPublish, AutoRunTests, etc.
- **TDD Session Settings**: RememberLastRun, AutoSaveResults, DetailLevel, etc.
- **Script Behavior Settings**: VerboseOutput, ErrorActionPreference, etc.

**Usage**: This file is loaded by `Get-TDDConfiguration.ps1` and used by all scripts in the TDD workflow.

#### Test-TDDEnvironment.ps1 (formerly Verify-Environment.ps1)

**Purpose**: Verifies the environment for Business Central TDD workflow by checking if required components are installed and running.

**Parameters**:
- `ConfigPath`: Path to the configuration file (default: "scripts\TDDConfig.psd1")

**Returns**: Boolean indicating if all checks passed

**Dependencies**:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`
- `Initialize-TDDEnvironment.ps1` (called if container doesn't exist)
- BcContainerHelper module

**Usage Examples**:
```powershell
# Basic verification
.\scripts\Test-TDDEnvironment.ps1

# Verification with custom configuration
.\scripts\Test-TDDEnvironment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"

# Verification before running tests
if (.\scripts\Test-TDDEnvironment.ps1) {
    # Environment is ready, proceed with tests
    .\scripts\Run-Tests.ps1
}
```

**Expected Output**:

Successful verification:
```
SUCCESS: BcContainerHelper module is installed and imported (Version: X.X.X)
SUCCESS: Docker is running
SUCCESS: The 'bctest' container exists and is running

All environment checks passed! The environment is ready for Business Central TDD workflow.
```

Issues detected with automatic remediation:
```
The 'bctest' container does not exist. Attempting to create it...
Calling Initialize-TDDEnvironment.ps1 to create the container...
SUCCESS: The 'bctest' container has been created and started successfully
```

The script returns an exit code of 0 if all checks pass, and 1 if any check fails, making it suitable for use in automated workflows.

### Integration with TDD Workflow

The scripts work together to provide a complete TDD workflow for Business Central:

1. `Test-TDDEnvironment.ps1` verifies the environment is ready
2. `Initialize-TDDEnvironment.ps1` sets up the environment if needed
3. `SetupTestContainer.ps1` creates the Business Central container
4. Additional scripts (to be implemented) will handle app compilation, publishing, and test execution

All scripts use the centralized configuration from `TDDConfig.psd1` loaded through `Get-TDDConfiguration.ps1` and common utility functions from `Common-Functions.ps1` for consistent behavior.