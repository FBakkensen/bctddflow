# Business Central TDD Workflow Implementation Plan

## Workflow Overview

This document outlines the step-by-step implementation plan for creating a Test-Driven Development (TDD) workflow for Business Central using Docker. The complete workflow consists of the following steps:

1. Compile the main application using alc.exe on the host machine (not in the container)
2. Compile the test application using alc.exe on the host machine (not in the container)
3. Deploy the compiled app packages (.app files) to the Business Central container named 'bctest'
4. Run all tests or selected tests from the test app in the container
5. View and analyze test results

The ultimate goal of this workflow is to enable a complete BDD/TDD workflow to implement new features in Business Central, where you can:
1. Implement test code first (following test-driven development principles)
2. Implement application code to satisfy the tests
3. Run the tests against the implemented code
4. Respond to test results (pass/fail) and make necessary adjustments
5. Iterate through steps 1-4 until the feature is fully implemented and all tests pass

Each task in this plan is designed to be atomic and builds upon previous tasks to create a complete workflow that supports this development approach.

## Environment Setup

### 1. [x] Create Environment Verification Script

**Prompt:**
```
Create a PowerShell script named 'Verify-Environment.ps1' in the scripts folder that checks if:
1. BcContainerHelper module is installed
2. Docker is running
3. The 'bctest' container exists and is running
The script should provide clear error messages if any requirements are not met and instructions on how to fix them.
```

**Verification:**
- Run `.\scripts\Verify-Environment.ps1`
- Script should output success message if all requirements are met
- If requirements are not met, script should provide clear error messages with instructions

### 2. [x] Create Environment Setup Script

**Prompt:**
```
Create a PowerShell script named 'Initialize-TDDEnvironment.ps1' in the scripts folder that:
1. Calls Verify-Environment.ps1 to ensure prerequisites are met
2. If the 'bctest' container doesn't exist, creates it with appropriate settings by calling SetupTestContainer.ps1
3. If the container exists but isn't running, starts it
4. Sets up any necessary environment variables for the TDD workflow
Include detailed comments explaining each step and any parameters that can be customized.
```

**Implementation Notes:**
- Enhance SetupTestContainer.ps1 to accept parameters for container name, image, auth, etc.
- Modify Initialize-TDDEnvironment.ps1 to call SetupTestContainer.ps1 for container creation
- Remove license file parameter as it's no longer needed for BC container creation
- Add proper handling of container information returned by SetupTestContainer.ps1

**Verification:**
- Run `.\scripts\Initialize-TDDEnvironment.ps1`
- Script should check environment and start the container if needed
- Verify container is running with `docker ps`
- Script should output success message with container details

## App Management

### 3. [x] Create Central Configuration File

**Prompt:**
```
Create a PowerShell Data File (PSD1) named 'TDDConfig.psd1' in the scripts directory that:
1. Centralizes all configuration settings for the TDD workflow
2. Includes environment settings (container name, artifact URL, auth method)
3. Defines path settings for source code and output directories
4. Specifies compilation settings (code analysis, warnings as errors)
5. Contains publishing settings (scope, sync mode, timeout)
6. Includes test settings (results path, timeout, fail behavior)
7. Provides watch mode and TDD session settings
8. Defines script behavior settings (error handling, verbosity)
Include detailed comments explaining each setting and available options.
```

**Verification:**
- Review `scripts\TDDConfig.psd1` for completeness
- Verify all settings have appropriate default values
- Check that comments explain each setting clearly
- Test importing the file using `Import-PowerShellDataFile -Path ".\scripts\TDDConfig.psd1"`

### 3.1. [x] Update Verify-Environment Script to Use Configuration

**Prompt:**
```
Modify the 'Verify-Environment.ps1' script in the scripts folder to:
1. Import and use settings from the TDDConfig.psd1 file
2. Use the ContainerName setting from the configuration instead of hardcoded 'bctest'
3. Add a parameter to override the configuration file path
4. Maintain backward compatibility by using default values if configuration cannot be loaded
5. Update error messages to reference the configuration file when appropriate
6. Add comments explaining the configuration integration
```

**Verification:**
- Run `.\scripts\Verify-Environment.ps1` (should use container name from config)
- Run `.\scripts\Verify-Environment.ps1 -ConfigPath "custom-config.psd1"` (should use custom config if provided)
- Verify error messages reference the configuration file when appropriate
- Check that the script works even if the configuration file is missing (using defaults)
- Confirm the script correctly uses the container name from configuration

### 3.2. [x] Update SetupTestContainer Script to Use Configuration

**Prompt:**
```
Modify the 'SetupTestContainer.ps1' script in the scripts folder to:
1. Import and use settings from the TDDConfig.psd1 file
2. Use environment settings from configuration (ContainerName, ArtifactUrl, Auth, etc.)
3. Add a parameter to override the configuration file path
4. Apply container creation options from configuration (MemoryLimit, Accept_Eula, etc.)
5. Use test toolkit settings from configuration (IncludeTestToolkit, IncludePerformanceToolkit)
6. Maintain backward compatibility by using default values if configuration cannot be loaded
7. Add comments explaining the configuration integration
```

**Verification:**
- Run `.\scripts\SetupTestContainer.ps1` (should use settings from config)
- Run `.\scripts\SetupTestContainer.ps1 -ConfigPath "custom-config.psd1"` (should use custom config if provided)
- Verify container is created with settings from configuration
- Check that the script works even if the configuration file is missing (using defaults)
- Confirm container properties match those specified in the configuration

### 3.3. [x] Update Initialize-TDDEnvironment Script to Use Configuration

**Prompt:**
```
Modify the 'Initialize-TDDEnvironment.ps1' script in the scripts folder to:
1. Import and use settings from the TDDConfig.psd1 file
2. Use environment settings from configuration (ContainerName, ArtifactUrl, Auth, etc.)
3. Add a parameter to override the configuration file path
4. Pass configuration settings to SetupTestContainer.ps1 when creating the container
5. Set environment variables based on configuration settings
6. Maintain backward compatibility by using default values if configuration cannot be loaded
7. Add comments explaining the configuration integration
8. Update output messages to include configuration information
```

**Verification:**
- Run `.\scripts\Initialize-TDDEnvironment.ps1` (should use settings from config)
- Run `.\scripts\Initialize-TDDEnvironment.ps1 -ConfigPath "custom-config.psd1"` (should use custom config if provided)
- Verify container is created with settings from configuration
- Check that environment variables are set based on configuration
- Confirm the script works even if the configuration file is missing (using defaults)
- Verify output messages include configuration information

### 4. [x] Create Configuration Helper Script

**Prompt:**
```
Create a PowerShell script named 'Get-TDDConfiguration.ps1' in the scripts folder that:
1. Provides a function to load the TDDConfig.psd1 file
2. Validates required configuration settings
3. Allows overriding settings via parameters
4. Merges default settings with user-provided settings
5. Returns a complete configuration object for use in other scripts
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Get-TDDConfiguration.ps1`
- Script should load and return the configuration
- Verify validation of required settings
- Test overriding settings with parameters
- Check error handling for missing or invalid configuration

### 4.1. [x] Refactor Verify-Environment.ps1 to Use Get-TDDConfiguration

**Prompt:**
```
Refactor the 'Verify-Environment.ps1' script in the scripts folder to:
1. Remove the custom Import-TDDConfiguration function
2. Use the Get-TDDConfiguration.ps1 script for loading configuration
3. Pass through any ConfigPath parameter to Get-TDDConfiguration
4. Maintain the same functionality and error handling
5. Update comments to reflect the use of centralized configuration management
```

**Verification:**
- Run `.\scripts\Verify-Environment.ps1`
- Script should work the same as before but use Get-TDDConfiguration
- Verify error handling still works correctly
- Check that the script passes the ConfigPath parameter correctly
- Confirm the script uses the container name from the configuration

### 4.2. [x] Refactor Initialize-TDDEnvironment.ps1 to Use Get-TDDConfiguration

**Prompt:**
```
Refactor the 'Initialize-TDDEnvironment.ps1' script in the scripts folder to:
1. Remove the custom Import-TDDConfiguration function
2. Use the Get-TDDConfiguration.ps1 script for loading configuration
3. Pass through any ConfigPath parameter to Get-TDDConfiguration
4. Maintain the same functionality and error handling
5. Update comments to reflect the use of centralized configuration management
```

**Verification:**
- Run `.\scripts\Initialize-TDDEnvironment.ps1`
- Script should work the same as before but use Get-TDDConfiguration
- Verify error handling still works correctly
- Check that the script passes the ConfigPath parameter correctly
- Confirm the script uses settings from the configuration

### 4.3. [x] Refactor SetupTestContainer.ps1 to Use Get-TDDConfiguration

**Prompt:**
```
Refactor the 'SetupTestContainer.ps1' script in the scripts folder to:
1. Remove the custom Import-TDDConfiguration function
2. Use the Get-TDDConfiguration.ps1 script for loading configuration
3. Pass through any ConfigPath parameter to Get-TDDConfiguration
4. Maintain the same functionality and error handling
5. Update comments to reflect the use of centralized configuration management
```

**Verification:**
- Run `.\scripts\SetupTestContainer.ps1`
- Script should work the same as before but use Get-TDDConfiguration
- Verify error handling still works correctly
- Check that the script passes the ConfigPath parameter correctly
- Confirm the script uses settings from the configuration

### 4.4. [x] Create Common Functions Script

**Prompt:**
```
Create a PowerShell script named 'Common-Functions.ps1' in the scripts folder that:
1. Provides common utility functions used across multiple scripts
2. Includes functions for displaying messages (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage)
3. Includes function for importing BcContainerHelper module
4. Includes other common helper functions
5. Has proper documentation and help information
```

**Verification:**
- Review `.\scripts\Common-Functions.ps1` for completeness
- Verify all common functions are included
- Check that the functions work correctly
- Test importing the script in other scripts

### 4.5. [x] Refactor Verify-Environment.ps1 to Use Common-Functions.ps1

**Prompt:**
```
Refactor the 'Verify-Environment.ps1' script in the scripts folder to:
1. Dot-source the Common-Functions.ps1 script at the beginning
2. Replace custom message functions with those from Common-Functions.ps1 (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, Write-WarningMessage)
3. Replace the Import-BcContainerHelperIfAvailable function with Import-BcContainerHelperModule from Common-Functions.ps1
4. Replace Docker status check functions with Test-DockerRunning, Test-DockerContainerExists, and Test-DockerContainerRunning from Common-Functions.ps1
5. Use Invoke-ScriptWithErrorHandling for error-prone operations
6. Update comments to reflect the use of Common-Functions.ps1
7. Maintain the same functionality and error handling
```

**Verification:**
- Run `.\scripts\Verify-Environment.ps1`
- Script should work the same as before but use Common-Functions.ps1
- Verify error handling still works correctly
- Check that the script uses the common functions for message display and Docker operations
- Confirm the script correctly imports BcContainerHelper using the common function

**Dependencies:**
- Task 4.4 (Create Common Functions Script)

### 4.6. [x] Refactor Initialize-TDDEnvironment.ps1 to Use Common-Functions.ps1

**Prompt:**
```
Refactor the 'Initialize-TDDEnvironment.ps1' script in the scripts folder to:
1. Dot-source the Common-Functions.ps1 script at the beginning
2. Replace custom message functions with those from Common-Functions.ps1 (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, Write-WarningMessage)
3. Replace the Import-BcContainerHelperIfAvailable function with Import-BcContainerHelperModule from Common-Functions.ps1
4. Replace Docker status check code with Test-DockerRunning, Test-DockerContainerExists, and Test-DockerContainerRunning from Common-Functions.ps1
5. Use Get-DockerContainerInfo for retrieving container information
6. Use Invoke-ScriptWithErrorHandling for error-prone operations
7. Use Resolve-TDDPath for path resolution
8. Update comments to reflect the use of Common-Functions.ps1
9. Maintain the same functionality and error handling
```

**Verification:**
- Run `.\scripts\Initialize-TDDEnvironment.ps1`
- Script should work the same as before but use Common-Functions.ps1
- Verify error handling still works correctly
- Check that the script uses the common functions for message display, Docker operations, and path resolution
- Confirm the script correctly imports BcContainerHelper using the common function

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 (Refactor Verify-Environment.ps1 to Use Common-Functions.ps1)

### 4.7. [x] Refactor SetupTestContainer.ps1 to Use Common-Functions.ps1

**Prompt:**
```
Refactor the 'SetupTestContainer.ps1' script in the scripts folder to:
1. Dot-source the Common-Functions.ps1 script at the beginning
2. Replace custom message functions with those from Common-Functions.ps1 (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, Write-WarningMessage)
3. Replace the Import-BcContainerHelperIfAvailable function with Import-BcContainerHelperModule from Common-Functions.ps1
4. Use Test-ValidCredential for credential validation
5. Use Test-ValidContainerName for container name validation
6. Use Test-ValidAuthMethod for authentication method validation
7. Use Invoke-ScriptWithErrorHandling for error-prone operations
8. Use Get-DockerContainerInfo for retrieving container information
9. Update comments to reflect the use of Common-Functions.ps1
10. Maintain the same functionality and error handling
```

**Verification:**
- Run `.\scripts\SetupTestContainer.ps1`
- Script should work the same as before but use Common-Functions.ps1
- Verify error handling still works correctly
- Check that the script uses the common functions for message display, validation, and Docker operations
- Confirm the script correctly imports BcContainerHelper using the common function

**Dependencies:**
- Task 4.4 (Create Common Functions Script)

### 4.8. [x] Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1

**Prompt:**
```
Refactor the 'Get-TDDConfiguration.ps1' script in the scripts folder to:
1. Dot-source the Common-Functions.ps1 script at the beginning
2. Replace any custom message functions with those from Common-Functions.ps1 (Write-InfoMessage, Write-SuccessMessage, Write-ErrorMessage, Write-WarningMessage)
3. Use Resolve-TDDPath for path resolution
4. Use Test-PathIsFile to check if the configuration file exists
5. Use Invoke-ScriptWithErrorHandling for error-prone operations
6. Update comments to reflect the use of Common-Functions.ps1
7. Maintain the same functionality and error handling
```

**Verification:**
- Run `.\scripts\Get-TDDConfiguration.ps1`
- Script should work the same as before but use Common-Functions.ps1
- Verify error handling still works correctly
- Check that the script uses the common functions for message display, path resolution, and file operations
- Confirm other scripts that use Get-TDDConfiguration.ps1 still work correctly

**Dependencies:**
- Task 4.4 (Create Common Functions Script)

### 4.9. [x] Create Script Template Using Common-Functions.ps1

**Prompt:**
```
Create a PowerShell script template named 'Script-Template.ps1' in the scripts folder that:
1. Includes standard script header with synopsis, description, parameters, examples, and notes
2. Dot-sources the Common-Functions.ps1 script
3. Sets up error handling preferences
4. Loads configuration using Get-TDDConfiguration.ps1
5. Includes a main function with proper error handling using Invoke-ScriptWithErrorHandling
6. Includes parameter validation using common validation functions
7. Uses common message functions for output
8. Includes comments explaining how to use the template for new scripts
9. Returns a strongly-typed PSCustomObject with results
```

**Verification:**
- Review `.\scripts\Script-Template.ps1` for completeness
- Verify the template includes all necessary components
- Check that the template can be used as a starting point for new scripts
- Test the template by creating a simple script based on it

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)

### 5. [x] Create App Source Preparation Script

**Prompt:**
```
Create a PowerShell script named 'Prepare-AppSource.ps1' in the scripts folder that:
1. Takes parameters for source directory, output directory, and app type (main/test) with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Creates the output directory if it doesn't exist
6. Copies the AL source files to the output directory, excluding any temporary or build files
7. Validates the app.json file for required fields (publisher, name, version)
8. Handles errors gracefully with clear error messages
9. Returns a strongly-typed [pscustomobject] with results
10. Provides feedback on successful preparation
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Prepare-AppSource.ps1 -AppType "Main"` (should use default paths from config for main app)
- Run `.\scripts\Prepare-AppSource.ps1 -AppType "Test"` (should use default paths from config for test app)
- Run `.\scripts\Prepare-AppSource.ps1 -SourceDirectory ".\app" -OutputDirectory ".\build\app" -AppType "Main"` (should override config)
- Script should create the output directory and copy source files
- Verify app.json is validated
- Check output directory contains all necessary files
- Verify successful output message
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)

### 6. [x] Create App Compilation Script (Completed)

**Prompt:**
```
Create a PowerShell script named 'Compile-App.ps1' in the scripts folder that:
1. Takes parameters for app source directory, output directory, and app type (main/test) with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Uses alc.exe on the host machine (not in the container) to compile the app
6. Applies compiler options from the configuration (code analysis, treat warnings as errors)
7. Outputs the compiled app file (.app) to the specified output directory
8. Returns a strongly-typed [pscustomobject] with compilation results
9. Provides feedback on successful compilation including app version and file location
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Compile-App.ps1 -AppType "Main"` (should use default paths from config for main app)
- Run `.\scripts\Compile-App.ps1 -AppType "Test"` (should use default paths from config for test app)
- Run `.\scripts\Compile-App.ps1 -AppSourceDirectory ".\build\app" -OutputDirectory ".\build\output" -AppType "Main"` (should override config)
- Script should compile the app using alc.exe on the host machine
- Verify .app file is created in the output directory
- Check compilation errors are properly reported
- Verify successful output message with app details
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 5 (Create App Source Preparation Script)

### 7. [ ] Create App Deployment Script

**Prompt:**
```
Create a PowerShell script named 'Deploy-App.ps1' in the scripts folder that:
1. Takes parameters for compiled app file path (.app file), container name, and app type (main/test) with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Verifies the container exists and is running using structured Docker output formats
6. Uses BcContainerHelper to publish the specified app to the container with proper error handling
7. Uses the specific pattern for Business Central container operations with explicit parameters
8. Applies publishing settings from the configuration (scope, sync mode, timeout)
9. Handles dependencies appropriately (test app depends on main app)
10. Returns a strongly-typed [pscustomobject] with deployment results
11. Provides feedback on successful deployment including app details
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Deploy-App.ps1 -AppType "Main"` (should use default paths from config for main app)
- Run `.\scripts\Deploy-App.ps1 -AppType "Test"` (should use default paths from config for test app)
- Run `.\scripts\Deploy-App.ps1 -AppPath ".\build\output\app.app" -AppType "Main"` (should override config)
- Script should deploy the app to the container
- Verify successful output message
- Check app is published in container using BcContainerHelper
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)

### 8. [ ] Create Test Runner Script

**Prompt:**
```
Create a PowerShell script named 'Run-Tests.ps1' in the scripts folder that:
1. Takes parameters for container name, test codeunit ID/name, and result file path with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Verifies the container exists and is running using structured Docker output formats
6. Uses BcContainerHelper to run the specified tests in the container with proper error handling
7. Uses the specific pattern for Business Central container operations with explicit parameters
8. Applies test settings from the configuration (timeout, fail behavior)
9. Supports running all tests or specific test codeunits
10. Captures test results and formats them for easy reading
11. Returns a strongly-typed [pscustomobject] with test results
12. Returns appropriate exit code based on test success/failure
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Run-Tests.ps1` (should run all tests using config defaults)
- Run `.\scripts\Run-Tests.ps1 -TestCodeunit "HelloWorld Test"` (should run specific test)
- Verify test results are displayed correctly
- Check exit code is 0 for success and non-zero for failure
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 7 (Create App Deployment Script)

### 9. [ ] Create Test Results Viewer Script

**Prompt:**
```
Create a PowerShell script named 'View-TestResults.ps1' in the scripts folder that:
1. Takes a parameter for the test results file path with default from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Formats and displays test results in a readable format
6. Applies TDD session settings from the configuration (detail level, show passed tests)
7. Provides summary statistics (tests run, passed, failed)
8. Returns a strongly-typed [pscustomobject] with result summary
9. Highlights failed tests with details on why they failed
Include parameter validation and help information.
```

**Verification:**
- Run tests with `.\scripts\Run-Tests.ps1` (should use default result file path from config)
- Run `.\scripts\View-TestResults.ps1` (should use default result file path from config)
- Run `.\scripts\View-TestResults.ps1 -ResultFile "TestResults.xml"` (should override config)
- Verify results are displayed in a readable format
- Check summary statistics are accurate
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 8 (Create Test Runner Script)

### 10. [ ] Create TDD Workflow Script

**Prompt:**
```
Create a PowerShell script named 'Start-TDDWorkflow.ps1' in the scripts folder that:
1. Takes parameters for app source directory, test app source directory, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Verifies the container exists and is running using structured Docker output formats
6. Provides a complete workflow that:
   - Compiles the main application using alc.exe on the host machine
   - Compiles the test application using alc.exe on the host machine
   - Deploys the compiled app packages to the Business Central container
   - Runs all tests or selected tests from the test app in the container
   - Views and analyzes test results
7. Has switches to control which steps to execute
8. Uses the specific pattern for Business Central container operations with explicit parameters
9. Calls the individual scripts with appropriate parameters
10. Handles proper sequencing (main app before test app)
11. Returns a strongly-typed [pscustomobject] with workflow results
12. Provides consolidated feedback on the workflow process
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Start-TDDWorkflow.ps1` (should execute complete workflow with defaults)
- Run `.\scripts\Start-TDDWorkflow.ps1 -CompileOnly` (should only compile apps)
- Run `.\scripts\Start-TDDWorkflow.ps1 -DeployOnly` (should only deploy apps)
- Run `.\scripts\Start-TDDWorkflow.ps1 -TestOnly` (should only run tests)
- Verify appropriate output messages for each scenario
- Confirm the script uses the centralized configuration management
- Verify the script returns a properly structured object with results

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)
- Task 7 (Create App Deployment Script)
- Task 8 (Create Test Runner Script)
- Task 9 (Create Test Results Viewer Script)

## TDD Workflow Integration

### 11. [ ] Create Interactive TDD Session Script

**Prompt:**
```
Create a PowerShell script named 'Start-TDDSession.ps1' in the scripts folder that:
1. Uses Get-TDDConfiguration.ps1 to load configuration settings
2. Uses Common-Functions.ps1 for utility functions
3. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
4. Initializes the environment by calling Initialize-TDDEnvironment.ps1
5. Verifies the container exists and is running using structured Docker output formats
6. Uses the specific pattern for Business Central container operations with explicit parameters
7. Provides a menu-driven interface for the TDD workflow with options to:
   - Compile main app
   - Compile test app
   - Deploy main app
   - Deploy test app
   - Run all tests
   - Run specific tests
   - View test results
   - Edit configuration settings
   - Exit the session
8. Applies TDD session settings from the configuration (remember last run, auto-save results)
9. Maintains state between commands according to configuration
10. Returns strongly-typed [pscustomobject] results for each operation
11. Provides clear feedback after each action
Include detailed help information and usage examples.
```

**Verification:**
- Run `.\scripts\Start-TDDSession.ps1`
- Navigate through menu options and verify each works correctly
- Verify state is maintained between commands according to configuration
- Test editing configuration settings through the menu
- Check feedback is clear and helpful
- Confirm the script uses the centralized configuration management
- Verify the script returns properly structured objects with results for each operation

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)
- Task 7 (Create App Deployment Script)
- Task 8 (Create Test Runner Script)
- Task 9 (Create Test Results Viewer Script)
- Task 10 (Create TDD Workflow Script)

### 12. [ ] Create Watch Mode Script

**Prompt:**
```
Create a PowerShell script named 'Watch-Changes.ps1' in the scripts folder that:
1. Takes parameters for app path, test app path, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
5. Verifies the container exists and is running using structured Docker output formats
6. Uses the specific pattern for Business Central container operations with explicit parameters
7. Applies watch mode settings from the configuration (interval, auto-publish, auto-run tests)
8. Watches for changes in the specified directories
9. When changes are detected, automatically:
   - Compiles the changed app(s) using alc.exe on the host machine
   - Deploys the changed app(s) to the container
   - Runs the tests
   - Displays the results
10. Returns strongly-typed [pscustomobject] results for each operation
11. Continues watching until manually stopped
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Watch-Changes.ps1` (should use default paths from config)
- Run `.\scripts\Watch-Changes.ps1 -AppPath ".\app" -TestAppPath ".\test"` (should override config)
- Make a change to a file in the app directory
- Verify app is automatically compiled, deployed, and tests are run
- Make a change to a file in the test directory
- Verify test app is automatically compiled, deployed, and tests are run
- Check results are displayed correctly
- Confirm the script uses the centralized configuration management
- Verify the script returns properly structured objects with results for each operation

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)
- Task 7 (Create App Deployment Script)
- Task 8 (Create Test Runner Script)
- Task 9 (Create Test Results Viewer Script)
- Task 10 (Create TDD Workflow Script)

## Documentation

### 13. [ ] Create Workflow Documentation

**Prompt:**
```
Create a markdown file named 'TDD-Workflow.md' in the root directory that:
1. Explains the TDD workflow for Business Central
2. Provides detailed instructions for using each script
3. Includes examples for common scenarios with exact command syntax
4. Documents the app compilation, deployment, and testing workflow
5. Explains how to customize the workflow for specific needs through the TDDConfig.psd1 file
6. Includes troubleshooting information for common issues
7. Documents the proper error handling practices used in the scripts
8. Explains the use of structured Docker output formats for container operations
9. Describes the specific pattern for Business Central container operations
10. Includes information about the strongly-typed objects returned by each script
The documentation should be comprehensive but easy to follow.
```

**Verification:**
- Review `TDD-Workflow.md` for completeness and accuracy
- Verify all scripts are documented with examples
- Check troubleshooting section covers common issues
- Verify the documentation includes information about error handling
- Confirm the documentation explains the use of structured Docker output formats
- Check that the documentation describes the specific pattern for Business Central container operations
- Verify the documentation includes information about the strongly-typed objects returned by each script

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 12 (All script creation tasks)

### 14. [ ] Update README.md

**Prompt:**
```
Update the README.md file in the root directory to:
1. Add a section about the TDD workflow
2. Provide a brief overview of the available scripts
3. Link to the detailed TDD-Workflow.md documentation
4. Include a quick start guide for getting started with TDD
5. Document the centralized configuration management approach
6. Explain the proper error handling practices used in the scripts
7. Describe the use of structured Docker output formats for container operations
8. Explain the specific pattern for Business Central container operations
9. Include information about the strongly-typed objects returned by each script
The updates should integrate well with the existing README content.
```

**Verification:**
- Review updated README.md
- Verify TDD workflow section is added
- Check links to documentation work correctly
- Ensure quick start guide is clear and concise
- Verify the README includes information about centralized configuration management
- Confirm the README explains proper error handling practices
- Check that the README describes the use of structured Docker output formats
- Verify the README explains the specific pattern for Business Central container operations
- Confirm the README includes information about strongly-typed objects

**Dependencies:**
- Task 13 (Create Workflow Documentation)

## Testing and Refinement

### 15. [ ] Create Example Test and Implementation

**Prompt:**
```
Create an example test and implementation to demonstrate the TDD workflow:
1. Create a test codeunit in the test app that tests a new feature
2. Create the implementation in the main app that makes the test pass
3. Document the example in a markdown file named 'TDD-Example.md' in the .aiwork directory
4. Include step-by-step instructions for using the TDD workflow scripts with this example
5. Show how to use the centralized configuration management
6. Demonstrate proper error handling practices
7. Show the use of structured Docker output formats for container operations
8. Demonstrate the specific pattern for Business Central container operations
9. Show how to interpret the strongly-typed objects returned by each script
The example should be simple but illustrative of the TDD process.
```

**Verification:**
- Review the test and implementation code
- Follow the TDD workflow with the example
- Verify tests fail initially and pass after implementation
- Check documentation clearly explains the example
- Verify the example demonstrates centralized configuration management
- Confirm the example shows proper error handling practices
- Check that the example demonstrates the use of structured Docker output formats
- Verify the example shows the specific pattern for Business Central container operations
- Confirm the example shows how to interpret the strongly-typed objects returned by each script

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 12 (All script creation tasks)

### 16. [ ] Perform End-to-End Workflow Test

**Prompt:**
```
Perform an end-to-end test of the TDD workflow and document the results:
1. Verify and update the scripts\TDDConfig.psd1 file with appropriate settings
2. Start with the Initialize-TDDEnvironment.ps1 script
3. Compile the main app using Compile-App.ps1
4. Compile the test app using Compile-App.ps1
5. Deploy the main app using Deploy-App.ps1
6. Deploy the test app using Deploy-App.ps1
7. Run tests using Run-Tests.ps1
8. View results using View-TestResults.ps1
9. Make a change to the test app that causes a test to fail
10. Recompile and redeploy the test app
11. Run tests to verify failure
12. Make a change to the main app to fix the test
13. Recompile and redeploy the main app
14. Run tests to verify success
15. Try the Start-TDDSession.ps1 script for an interactive workflow
16. Test the Watch-Changes.ps1 script for automatic workflow
17. Verify proper error handling in all scripts
18. Confirm the use of structured Docker output formats for container operations
19. Validate the specific pattern for Business Central container operations
20. Check the strongly-typed objects returned by each script
21. Document any issues or improvements needed
```

**Verification:**
- Complete the end-to-end workflow
- Verify each step works as expected
- Document any issues or improvements needed
- Make necessary script adjustments
- Verify proper error handling in all scripts
- Confirm the use of structured Docker output formats for container operations
- Validate the specific pattern for Business Central container operations
- Check the strongly-typed objects returned by each script

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 12 (All script creation tasks)
- Task 15 (Create Example Test and Implementation)

### 17. [ ] Refine Scripts Based on Testing

**Prompt:**
```
Refine the scripts based on the end-to-end testing:
1. Address any issues identified during testing
2. Improve error handling and feedback
3. Optimize performance where possible
4. Ensure consistent parameter naming and behavior across scripts
5. Verify proper use of structured Docker output formats for container operations
6. Validate the specific pattern for Business Central container operations
7. Ensure all scripts return strongly-typed [pscustomobject] results
8. Verify all scripts use the centralized configuration management
9. Ensure all scripts follow PSScriptAnalyzer guidelines
10. Update documentation to reflect any changes
```

**Verification:**
- Review and test all script changes
- Verify issues are resolved
- Check documentation is updated
- Perform another end-to-end test to confirm improvements
- Verify proper error handling in all scripts
- Confirm the use of structured Docker output formats for container operations
- Validate the specific pattern for Business Central container operations
- Check the strongly-typed objects returned by each script
- Verify all scripts use the centralized configuration management
- Ensure all scripts follow PSScriptAnalyzer guidelines

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 12 (All script creation tasks)
- Task 16 (Perform End-to-End Workflow Test)

## Final Integration

### 18. [ ] Create Master Script

**Prompt:**
```
Create a master script named 'TDD-Workflow.ps1' in the scripts folder that:
1. Uses Get-TDDConfiguration.ps1 to load configuration settings
2. Uses Common-Functions.ps1 for utility functions
3. Sets explicit error handling preferences ($ErrorActionPreference = 'Stop')
4. Verifies the container exists and is running using structured Docker output formats
5. Uses the specific pattern for Business Central container operations with explicit parameters
6. Provides a single entry point for all TDD workflow functions
7. Includes command-line parameters for all major functions with defaults from configuration
8. Supports both interactive and non-interactive modes
9. Can be used in CI/CD pipelines
10. Allows overriding configuration settings via parameters
11. Returns strongly-typed [pscustomobject] results for each operation
12. Follows PSScriptAnalyzer guidelines
13. Includes comprehensive help information
This should be a unified interface for the entire TDD workflow.
```

**Verification:**
- Run `.\scripts\TDD-Workflow.ps1 -Help` to view help information
- Test various command-line parameters
- Verify both interactive and non-interactive modes work
- Check script can be used in a CI/CD context
- Confirm the script uses the centralized configuration management
- Verify proper error handling in the script
- Confirm the use of structured Docker output formats for container operations
- Validate the specific pattern for Business Central container operations
- Check the strongly-typed objects returned by the script
- Verify the script follows PSScriptAnalyzer guidelines

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 5 through 12 (All script creation tasks)
- Task 17 (Refine Scripts Based on Testing)

### 19. [ ] Final Documentation Update

**Prompt:**
```
Update all documentation to reflect the final state of the TDD workflow:
1. Create a comprehensive TDD-Workflow.md document in the root directory that:
   - Explains the TDD workflow for Business Central
   - Provides detailed instructions for using each script
   - Includes examples for common scenarios with exact command syntax
   - Documents the app compilation, deployment, and testing workflow
2. Update README.md with:
   - A section about the TDD workflow
   - A brief overview of the available scripts
   - Links to the detailed TDD-Workflow.md documentation
   - A quick start guide for getting started with TDD
3. Create a quick reference card as TDD-QuickRef.md in the .aiwork directory
4. Create a configuration guide as TDD-Configuration.md explaining all settings in scripts\TDDConfig.psd1
5. Create a best practices guide as TDD-BestPractices.md explaining:
   - Proper error handling practices
   - Use of structured Docker output formats
   - Specific pattern for Business Central container operations
   - Strongly-typed objects for script results
   - PSScriptAnalyzer compliance
6. Ensure all examples and instructions are accurate
7. Include information about customizing the workflow through configuration settings
```

**Verification:**
- Review all documentation for accuracy and completeness
- Verify quick reference card covers all essential commands
- Check configuration guide explains all settings clearly
- Verify best practices guide covers all required topics
- Test examples work as described
- Ensure documentation is user-friendly and explains how to customize the workflow

**Dependencies:**
- Task 5 through 18 (All script creation and refinement tasks)

### 20. [ ] Create AI Assistant Integration Guide

**Prompt:**
```
Create a markdown file named 'AI-Assistant-Integration.md' in the .aiwork directory that:
1. Explains how an AI assistant can use the TDD workflow to implement new features in Business Central
2. Provides step-by-step instructions for the AI assistant to:
   - Understand the requirements for a new feature
   - Implement test code first (following test-driven development principles)
   - Implement application code to satisfy the tests
   - Run the tests against the implemented code
   - Respond to test results (pass/fail) and make necessary adjustments
   - Iterate through the process until the feature is fully implemented and all tests pass
3. Includes examples of prompts and interactions with the AI assistant
4. Provides guidance on how to structure requirements for optimal AI understanding
5. Explains how to interpret and act on the AI assistant's responses
6. Includes troubleshooting information for common issues
7. Documents best practices for working with the AI assistant on Business Central development
The guide should be comprehensive but easy to follow.
```

**Verification:**
- Review `AI-Assistant-Integration.md` for completeness and accuracy
- Verify the guide covers all aspects of using an AI assistant with the TDD workflow
- Check examples are clear and illustrative
- Ensure the guide provides practical advice for working with an AI assistant
- Verify troubleshooting section covers common issues
- Confirm the guide explains how to structure requirements for optimal AI understanding

**Dependencies:**
- Task 5 through 19 (All script creation, refinement, and documentation tasks)

### 21. [ ] Conduct Final Review and Validation

**Prompt:**
```
Conduct a final review and validation of the entire TDD workflow implementation:
1. Verify all scripts work correctly and follow the established patterns
2. Ensure all documentation is accurate and up-to-date
3. Validate that the workflow supports the complete TDD process:
   - Compiling the main application using alc.exe on the host machine
   - Compiling the test application using alc.exe on the host machine
   - Deploying the compiled app packages to the Business Central container
   - Running all tests or selected tests from the test app in the container
   - Viewing and analyzing test results
4. Confirm that the workflow enables the ultimate goal of implementing new features using TDD principles
5. Check that all scripts use proper error handling, structured Docker output formats, and return strongly-typed objects
6. Verify all scripts follow PSScriptAnalyzer guidelines
7. Ensure the configuration system is flexible and well-documented
8. Test the workflow with a simple end-to-end example
9. Document any remaining issues or future enhancements
```

**Verification:**
- Complete a full end-to-end test of the workflow
- Verify all scripts work as expected
- Check all documentation is accurate and helpful
- Confirm the workflow supports the complete TDD process
- Verify the workflow enables implementing new features using TDD principles
- Document any remaining issues or future enhancements

**Dependencies:**
- Task 5 through 20 (All previous tasks)
