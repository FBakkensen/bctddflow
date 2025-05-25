# Business Central TDD Workflow Documentation

## Overview

This document provides comprehensive documentation for the Test-Driven Development (TDD) workflow for Business Central using Docker. The workflow enables developers to follow TDD principles when developing Business Central extensions by providing a structured approach to:

1. Implementing test code first
2. Implementing application code to satisfy the tests
3. Running tests against the implemented code
4. Responding to test results and making necessary adjustments
5. Iterating through the process until the feature is fully implemented

## Scripts Folder Structure

The TDD workflow scripts are organized in a hierarchical structure for better maintainability and discoverability:

```
scripts/
├── Start-TDDSession.ps1          # Interactive session interface
├── Start-TDDWorkflow.ps1         # Complete workflow orchestrator
├── Initialize-TDDEnvironment.ps1 # Environment setup entry point
├── lib/                          # Core library functions
│   ├── Common-Functions.ps1      # Utility functions
│   └── Get-TDDConfiguration.ps1  # Configuration management
├── workflow/                     # Individual workflow step scripts
│   ├── Prepare-AppSource.ps1     # Source preparation
│   ├── Compile-App.ps1           # App compilation
│   ├── Deploy-App.ps1            # App deployment
│   ├── Run-Tests.ps1             # Test execution
│   └── View-TestResults.ps1      # Results viewing
├── internal/                     # Internal helper scripts
│   ├── Verify-Environment.ps1    # Environment verification
│   └── SetupTestContainer.ps1    # Container setup
└── config/                       # Configuration and templates
    ├── TDDConfig.psd1            # Configuration data
    └── Script-Template.ps1       # Script development template
```

**Key Benefits of the New Structure**:
- **Clear separation** of user-facing vs internal scripts
- **Logical grouping** of related functionality
- **Improved discoverability** for new users
- **Better maintainability** for developers
- **Professional organization** following industry standards

## Workflow Steps

The complete TDD workflow consists of the following steps:

1. **Prepare Source Code**: Copy source files from the main and test apps to build directories
2. **Compile Applications**: Compile the main and test applications using alc.exe on the host machine
3. **Deploy Applications**: Deploy the compiled app packages (.app files) to the Business Central container
4. **Run Tests**: Execute tests from the test app in the container
5. **View Results**: Analyze test results to determine if the implementation meets requirements

## Environment Setup

Before using the TDD workflow, you need to set up the environment:

### Prerequisites

- Docker Desktop installed and running
- PowerShell 5.1 or later
- BcContainerHelper module installed
- Business Central Docker container (created automatically if not present)

### Initialization

To initialize the environment, run:

```powershell
.\scripts\Initialize-TDDEnvironment.ps1
```

This script:
- Verifies that BcContainerHelper is installed
- Checks if Docker is running
- Creates the Business Central container if it doesn't exist
- Starts the container if it's stopped

## Script Documentation

### Verify-Environment.ps1

**Purpose**: Checks if the required components are installed and running.

**Location**: `scripts\internal\Verify-Environment.ps1`

**Parameters**:
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
.\scripts\internal\Verify-Environment.ps1
```

**Example Output**:
```
SUCCESS: BcContainerHelper module is installed and imported (Version: 3.0.12)
SUCCESS: Docker is running
SUCCESS: The 'bctest' container exists and is running

All environment checks passed! The environment is ready for Business Central TDD workflow.
```

### Initialize-TDDEnvironment.ps1

**Purpose**: Sets up the environment for the TDD workflow.

**Parameters**:
- `ConfigPath`: Path to the configuration file (optional)
- `ContainerName`: Name of the container (default: from config)
- `Auth`: Authentication method (default: from config)

**Usage**:
```powershell
.\scripts\Initialize-TDDEnvironment.ps1
```

### Prepare-AppSource.ps1

**Purpose**: Prepares the source code for compilation.

**Location**: `scripts\workflow\Prepare-AppSource.ps1`

**Parameters**:
- `SourceDirectory`: Path to the source directory (default: from config)
- `OutputDirectory`: Path to the output directory (default: from config)
- `AppType`: Type of app to prepare ("Main" or "Test")
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
# Prepare main app
.\scripts\workflow\Prepare-AppSource.ps1 -AppType "Main"

# Prepare test app
.\scripts\workflow\Prepare-AppSource.ps1 -AppType "Test"
```

### Compile-App.ps1

**Purpose**: Compiles the app using alc.exe on the host machine.

**Location**: `scripts\workflow\Compile-App.ps1`

**Parameters**:
- `AppSourceDirectory`: Path to the app source directory (default: from config)
- `OutputDirectory`: Path to the output directory (default: from config)
- `AppType`: Type of app to compile ("Main" or "Test")
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
# Compile main app
.\scripts\workflow\Compile-App.ps1 -AppType "Main"

# Compile test app
.\scripts\workflow\Compile-App.ps1 -AppType "Test"
```

### Deploy-App.ps1

**Purpose**: Deploys the compiled app to the Business Central container.

**Location**: `scripts\workflow\Deploy-App.ps1`

**Parameters**:
- `AppPath`: Path to the compiled app file (default: from config)
- `ContainerName`: Name of the container (default: from config)
- `AppType`: Type of app to deploy ("Main" or "Test")
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
# Deploy main app
.\scripts\workflow\Deploy-App.ps1 -AppType "Main"

# Deploy test app
.\scripts\workflow\Deploy-App.ps1 -AppType "Test"
```

### Run-Tests.ps1

**Purpose**: Runs tests in the Business Central container.

**Location**: `scripts\workflow\Run-Tests.ps1`

**Parameters**:
- `ContainerName`: Name of the container (default: from config)
- `TestCodeunit`: Name or ID of test codeunit to run (default: "*" for all)
- `TestFunction`: Name of test function to run (default: "*" for all)
- `ExtensionId`: ID of the extension to test (optional, automatically read from `test\app.json` if not provided)
- `TestCodeunitRange`: BC-compatible filter string for loading test codeunits (optional, use "*" to load all)
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
# Run all tests (extension ID automatically read from test\app.json)
.\scripts\workflow\Run-Tests.ps1

# Run specific test codeunit
.\scripts\workflow\Run-Tests.ps1 -TestCodeunit "HelloWorld Test"

# Run tests with explicit extension ID
.\scripts\workflow\Run-Tests.ps1 -ExtensionId "12345678-1234-1234-1234-123456789012"

# Load all test codeunits using testCodeunitRange
.\scripts\workflow\Run-Tests.ps1 -TestCodeunitRange "*"

# Combine parameters for precise test filtering
.\scripts\workflow\Run-Tests.ps1 -TestCodeunit "HelloWorld Test" -TestCodeunitRange "*"
```

### View-TestResults.ps1

**Purpose**: Displays test results in a readable format.

**Location**: `scripts\workflow\View-TestResults.ps1`

**Parameters**:
- `ResultFile`: Path to the test results file (default: from config)
- `ShowPassed`: Whether to show passed tests (default: from config)
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
.\scripts\workflow\View-TestResults.ps1
```

## Complete Workflow Scripts

### Start-TDDWorkflow.ps1

**Purpose**: Orchestrates the complete TDD workflow.

**Parameters**:
- `ConfigPath`: Path to the configuration file (optional)
- `AppSourceDirectory`: Path to the main app source directory (default: from config)
- `TestAppSourceDirectory`: Path to the test app source directory (default: from config)
- `ContainerName`: Name of the container (default: from config)
- `PrepareOnly`: Only prepare the app source for compilation
- `CompileOnly`: Only prepare and compile the apps
- `DeployOnly`: Only deploy the apps
- `TestOnly`: Only run tests
- `SkipPrepare`: Skip the preparation step
- `SkipCompile`: Skip the compilation step
- `SkipDeploy`: Skip the deployment step
- `SkipTests`: Skip running tests
- `SkipResults`: Skip displaying test results
- `TestCodeunit`: Name or ID of test codeunit to run (default: "*" for all)
- `TestFunction`: Name of test function to run (default: "*" for all)
- `ExtensionId`: ID of the extension to test (optional, automatically read from `test\app.json` if not provided)
- `TestCodeunitRange`: BC-compatible filter string for loading test codeunits (optional, use "*" to load all)
- `Detailed`: Include detailed test information
- `ShowPassed`: Show passed tests in the output

**Usage**:
```powershell
# Execute complete workflow (extension ID automatically read from test\app.json)
.\scripts\Start-TDDWorkflow.ps1

# Only compile apps
.\scripts\Start-TDDWorkflow.ps1 -CompileOnly

# Only run tests with specific test codeunit
.\scripts\Start-TDDWorkflow.ps1 -TestOnly -TestCodeunit "HelloWorld Test"

# Run tests with explicit extension ID
.\scripts\Start-TDDWorkflow.ps1 -TestOnly -ExtensionId "12345678-1234-1234-1234-123456789012"

# Run tests with testCodeunitRange to load all test codeunits
.\scripts\Start-TDDWorkflow.ps1 -TestOnly -TestCodeunitRange "*"
```

### Start-TDDSession.ps1

**Purpose**: Provides an interactive menu-driven interface for the TDD workflow.

**Parameters**:
- `ConfigPath`: Path to the configuration file (optional)

**Usage**:
```powershell
.\scripts\Start-TDDSession.ps1
```

**Menu Options**:
1. Initialize Environment
2. Compile Main App
3. Compile Test App
4. Deploy Main App
5. Deploy Test App
6. Run All Tests
7. Run Specific Tests
8. View Test Results
9. Edit Configuration Settings
0. Exit Session

## Configuration

The TDD workflow is configured using the `TDDConfig.psd1` file located in the `scripts\config\` directory. This file contains settings for:

- Environment settings (container name, artifact URL, authentication method)
- Path settings (source and output directories)
- Compilation settings (code analysis, warnings as errors)
- Publishing settings (scope, sync mode, timeout)
- Test settings (timeout, fail behavior)
- TDD session settings (remember last run, auto-save results)
- Script behavior settings (error handling, verbosity)

### Example Configuration

```powershell
@{
    # Environment Settings
    ContainerName = "bctest"
    ArtifactUrl = ""  # Empty string means latest sandbox artifact will be used
    Auth = "NavUserPassword"

    # Path Settings
    SourcePaths = @{
        App = ".\app"
        Test = ".\test"
    }

    OutputPaths = @{
        Build = ".\build"
        AppSource = ".\build\app"
        TestSource = ".\build\test"
        AppOutput = ".\build\output"
        TestResults = ".\build\testresults"
    }

    # Additional settings omitted for brevity
}
```

## Common Scenarios

### Creating a New Feature with TDD

1. **Write Test First**:
   - Create a test codeunit in the test app that tests the new feature
   - Run the tests to verify they fail (since the feature isn't implemented yet)

2. **Implement the Feature**:
   - Implement the feature in the main app
   - Run the tests to verify they pass

3. **Refactor if Needed**:
   - Refactor the code while ensuring tests continue to pass

### Example TDD Workflow

```powershell
# 1. Initialize environment
.\scripts\Initialize-TDDEnvironment.ps1

# 2. Write test code in the test app

# 3. Compile and deploy test app to verify it fails
.\scripts\Start-TDDWorkflow.ps1 -TestOnly -TestCodeunit "MyFeature Test"
# (Tests should fail at this point)

# 4. Implement the feature in the main app

# 5. Compile and deploy both apps, run tests
.\scripts\Start-TDDWorkflow.ps1
# (Tests should pass if implementation is correct)
```

## Troubleshooting

### Common Issues

1. **Container Creation Fails**:
   - Ensure Docker is running
   - Check if the specified artifact URL is valid
   - Verify you have enough disk space and memory

2. **Compilation Errors**:
   - Check the compiler output for specific errors
   - Verify the app.json file has correct dependencies
   - Ensure the .alpackages directory contains required dependencies

3. **Test Execution Fails**:
   - Verify both main and test apps are deployed successfully
   - Check if the test codeunit exists in the test app
   - Ensure the test app has the correct dependencies on the main app

### Error Handling

All scripts in the TDD workflow use structured error handling with clear error messages. If an error occurs, the script will:

1. Display a detailed error message
2. Provide information about how to fix the issue
3. Return a non-zero exit code

## Best Practices

1. **Follow TDD Principles**:
   - Write tests before implementing features
   - Run tests frequently to ensure code works as expected
   - Refactor code while maintaining test coverage

2. **Use Structured Docker Output**:
   - The workflow uses structured Docker output formats for reliable container status checks
   - This ensures consistent behavior across different environments

3. **Proper Error Handling**:
   - All scripts use explicit error handling preferences
   - This ensures errors aren't swallowed and scripts fail appropriately

4. **Return Strongly-Typed Objects**:
   - Scripts return strongly-typed PSCustomObject results
   - This provides better tab-completion and type safety for callers