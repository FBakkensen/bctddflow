# Business Central TDD Workflow

## Overview

This repository provides a Test-Driven Development (TDD) workflow for Business Central using Docker. The workflow enables developers to follow TDD principles when developing Business Central extensions by providing a structured approach to:

1. Implementing test code first
2. Implementing application code to satisfy the tests
3. Running tests against the implemented code
4. Responding to test results and making necessary adjustments
5. Iterating through the process until the feature is fully implemented

Key features include:

- **Docker Integration** with automated container setup and management
- **Host-Based Compilation** using alc.exe on the host machine (not in the container)
- **Streamlined Deployment** of compiled apps to the Business Central container
- **Test Execution and Reporting** with structured test results
- **Interactive TDD Session** with a menu-driven interface
- **Centralized Configuration** for customizing the workflow

## Getting Started

To get started with the Business Central TDD workflow, follow these steps:

1. **Clone the Repository**: Clone this repository to your local machine.
2. **Install Prerequisites**: Ensure Docker Desktop is installed and running, and PowerShell 5.1 or later is available.
3. **Initialize Environment**: Run `.\scripts\Initialize-TDDEnvironment.ps1` to set up the Business Central container.
4. **Start TDD Session**: Run `.\scripts\Start-TDDSession.ps1` for an interactive TDD workflow experience.
5. **Write Tests First**: Create test codeunits in the test app that define the expected behavior.
6. **Implement Features**: Develop the application code to make the tests pass.
7. **Run Tests**: Execute tests to verify your implementation meets the requirements.

## TDD Workflow

The Business Central TDD workflow consists of the following steps:

1. **Prepare Source Code**: Copy source files from the main and test apps to build directories
2. **Compile Applications**: Compile the main and test applications using alc.exe on the host machine
3. **Deploy Applications**: Deploy the compiled app packages (.app files) to the Business Central container
4. **Run Tests**: Execute tests from the test app in the container
5. **View Results**: Analyze test results to determine if the implementation meets requirements

### Available Scripts

The following scripts are available to support the TDD workflow:

- **Initialize-TDDEnvironment.ps1**: Sets up the environment for the TDD workflow
- **Prepare-AppSource.ps1**: Prepares the source code for compilation
- **Compile-App.ps1**: Compiles the app using alc.exe on the host machine
- **Deploy-App.ps1**: Deploys the compiled app to the Business Central container
- **Run-Tests.ps1**: Runs tests in the Business Central container
- **View-TestResults.ps1**: Displays test results in a readable format
- **Start-TDDWorkflow.ps1**: Orchestrates the complete TDD workflow
- **Start-TDDSession.ps1**: Provides an interactive menu-driven interface for the TDD workflow

For detailed documentation on each script, including parameters and examples, see the [TDD-Workflow.md](TDD-Workflow.md) file.

### Quick Start Guide

To quickly get started with TDD in Business Central:

```powershell
# 1. Initialize environment
.\scripts\Initialize-TDDEnvironment.ps1

# 2. Start an interactive TDD session
.\scripts\Start-TDDSession.ps1

# Or run the complete workflow at once
.\scripts\Start-TDDWorkflow.ps1
```

## Implementation Details

### Centralized Configuration Management

The TDD workflow uses a centralized configuration approach with the following components:

- **TDDConfig.psd1**: A PowerShell Data File that contains all configuration settings
- **Get-TDDConfiguration.ps1**: A script that loads, validates, and merges configuration settings
- **Configuration Override**: All scripts accept a `-ConfigPath` parameter to use a custom configuration file
- **Parameter Override**: Scripts allow overriding specific configuration settings via parameters

This approach provides several benefits:

- **Consistency**: All scripts use the same configuration settings
- **Flexibility**: Configuration can be customized without modifying scripts
- **Maintainability**: Configuration changes are made in one place
- **Validation**: Configuration is validated to ensure required settings are present

Example configuration usage:

```powershell
# Load default configuration
$config = .\scripts\lib\Get-TDDConfiguration.ps1

# Override specific settings
$config = .\scripts\lib\Get-TDDConfiguration.ps1 -OverrideSettings @{
    ContainerName = "mycontainer"
    Auth = "Windows"
}
```

### Error Handling Practices

All scripts in the TDD workflow use structured error handling with the following practices:

- **Explicit Error Preferences**: Set `$ErrorActionPreference = 'Stop'` to ensure errors aren't swallowed
- **Try-Catch Blocks**: Use try-catch blocks to handle errors gracefully
- **Clear Error Messages**: Provide detailed error messages with instructions on how to fix issues
- **Exit Codes**: Return meaningful exit codes for use in automated workflows
- **Error Logging**: Log errors with timestamp and context information

### Structured Docker Output Formats

The TDD workflow uses structured Docker output formats for reliable container status checks:

- **JSON Output**: Use `docker inspect --format='{{json .}}' container` instead of parsing CLI text output
- **Specific Properties**: Extract specific properties using Go templates like `--format='{{.State.Running}}'`
- **Reliable Parsing**: Parse JSON output instead of using regex on text output
- **Error Handling**: Handle missing containers and properties gracefully

This approach ensures consistent behavior across different environments and prevents issues with text parsing.

### Business Central Container Operations

The TDD workflow follows a specific pattern for Business Central container operations:

- **BcContainerHelper Module**: Use the BcContainerHelper module for all container operations
- **Explicit Parameters**: Use explicit parameters instead of hashtables for clarity
- **Credential Handling**: Use SecureString or PSCredential types for passwords
- **Error Handling**: Handle container operation errors gracefully
- **Timeout Management**: Set appropriate timeouts for container operations

### Strongly-Typed Objects

All scripts in the TDD workflow return strongly-typed PSCustomObject results with the following benefits:

- **Tab Completion**: Provides better tab-completion for callers
- **Type Safety**: Ensures properties have consistent types
- **Documentation**: Self-documents the return value structure
- **Pipeline Support**: Enables easy use in PowerShell pipelines

Example return object structure:

```powershell
[PSCustomObject]@{
    Success = $true
    Message = "Operation completed successfully"
    Data = @{
        # Operation-specific data
    }
    Timestamp = Get-Date
}
```

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
. .\scripts\lib\Common-Functions.ps1

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
$config = .\scripts\lib\Get-TDDConfiguration.ps1

# Load with custom path
$config = .\scripts\lib\Get-TDDConfiguration.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"

# Override specific settings
$config = .\scripts\lib\Get-TDDConfiguration.ps1 -OverrideSettings @{
    ContainerName = "mycontainer"
    Auth = "Windows"
}

# Validate required settings
$config = .\scripts\lib\Get-TDDConfiguration.ps1 -RequiredSettings @(
    "ContainerName", "Auth", "MemoryLimit"
)

# Validate only
$isValid = .\scripts\lib\Get-TDDConfiguration.ps1 -ValidateOnly
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
Copy-Item .\scripts\config\Script-Template.ps1 .\scripts\My-NewScript.ps1

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
.\scripts\internal\SetupTestContainer.ps1

# Create container with custom settings
.\scripts\internal\SetupTestContainer.ps1 -ContainerName "mytest" -Auth "Windows" -Country "us"

# Create container with custom credentials
$securePassword = ConvertTo-SecureString "MyPassword" -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential("admin", $securePassword)
.\scripts\internal\SetupTestContainer.ps1 -Credential $credential
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

#### Verify-Environment.ps1

**Purpose**: Verifies the environment for Business Central TDD workflow by checking if required components are installed and running.

**Parameters**:
- `ConfigPath`: Path to the configuration file (default: "scripts\config\TDDConfig.psd1")

**Returns**: Boolean indicating if all checks passed

**Dependencies**:
- `Common-Functions.ps1`
- `Get-TDDConfiguration.ps1`
- `Initialize-TDDEnvironment.ps1` (called if container doesn't exist)
- BcContainerHelper module

**Usage Examples**:
```powershell
# Basic verification
.\scripts\internal\Verify-Environment.ps1

# Verification with custom configuration
.\scripts\internal\Verify-Environment.ps1 -ConfigPath "C:\MyProject\CustomConfig.psd1"

# Verification before running tests
if (.\scripts\internal\Verify-Environment.ps1) {
    # Environment is ready, proceed with tests
    .\scripts\workflow\Run-Tests.ps1
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

1. `Verify-Environment.ps1` verifies the environment is ready
2. `Initialize-TDDEnvironment.ps1` sets up the environment if needed
3. `SetupTestContainer.ps1` creates the Business Central container
4. Additional scripts (to be implemented) will handle app compilation, publishing, and test execution

All scripts use the centralized configuration from `TDDConfig.psd1` loaded through `Get-TDDConfiguration.ps1` and common utility functions from `Common-Functions.ps1` for consistent behavior.