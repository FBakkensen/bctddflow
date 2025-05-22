# Business Central TDD Workflow Implementation Plan

This document outlines the step-by-step implementation plan for creating a Test-Driven Development (TDD) workflow for Business Central using Docker. Each task is designed to be atomic and builds upon previous tasks to create a complete workflow.

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

### 4.5. [ ] Refactor Verify-Environment.ps1 to Use Common-Functions.ps1

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

### 4.6. [ ] Refactor Initialize-TDDEnvironment.ps1 to Use Common-Functions.ps1

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

### 4.7. [ ] Refactor SetupTestContainer.ps1 to Use Common-Functions.ps1

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

### 4.8. [ ] Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1

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

### 4.9. [ ] Create Script Template Using Common-Functions.ps1

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

### 5. [ ] Create App Source Preparation Script

**Prompt:**
```
Create a PowerShell script named 'Prepare-AppSource.ps1' in the scripts folder that:
1. Takes parameters for source directory, output directory, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Creates the output directory if it doesn't exist
5. Copies the AL source files to the output directory, excluding any temporary or build files
6. Validates the app.json file for required fields (publisher, name, version)
7. Handles errors gracefully with clear error messages
8. Provides feedback on successful preparation
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Prepare-AppSource.ps1` (should use default paths from config)
- Run `.\scripts\Prepare-AppSource.ps1 -SourceDirectory ".\app" -OutputDirectory ".\build\app"` (should override config)
- Script should create the output directory and copy source files
- Verify app.json is validated
- Check output directory contains all necessary files
- Verify successful output message
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)

### 6. [ ] Create App Compilation Script

**Prompt:**
```
Create a PowerShell script named 'Compile-App.ps1' in the scripts folder that:
1. Takes parameters for app source directory, output directory, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Uses BcContainerHelper to compile the app in the container
5. Applies compiler options from the configuration (code analysis, treat warnings as errors)
6. Outputs the compiled app file (.app) to the specified output directory
7. Handles errors gracefully with clear error messages
8. Provides feedback on successful compilation including app version and file location
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Compile-App.ps1` (should use default paths from config)
- Run `.\scripts\Compile-App.ps1 -AppSourceDirectory ".\build\app" -OutputDirectory ".\build\output"` (should override config)
- Script should compile the app in the container
- Verify .app file is created in the output directory
- Check compilation errors are properly reported
- Verify successful output message with app details
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 5 (Create App Source Preparation Script)

### 7. [ ] Create Test App Compilation Script

**Prompt:**
```
Create a PowerShell script named 'Compile-TestApp.ps1' in the scripts folder that:
1. Takes parameters for test app source directory, output directory, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Uses BcContainerHelper to compile the test app in the container
5. Applies compiler options from the configuration (code analysis, treat warnings as errors)
6. Outputs the compiled test app file (.app) to the specified output directory
7. Handles errors gracefully with clear error messages
8. Provides feedback on successful compilation including app version and file location
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Compile-TestApp.ps1` (should use default paths from config)
- Run `.\scripts\Compile-TestApp.ps1 -TestAppSourceDirectory ".\build\test" -OutputDirectory ".\build\output"` (should override config)
- Script should compile the test app in the container
- Verify test .app file is created in the output directory
- Check compilation errors are properly reported
- Verify successful output message with app details
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)

### 8. [ ] Create App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-App.ps1' in the scripts folder that:
1. Takes parameters for compiled app file path (.app file) and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Uses BcContainerHelper to publish the specified app to the container
5. Applies publishing settings from the configuration (scope, sync mode, timeout)
6. Handles errors gracefully with clear error messages
7. Provides feedback on successful publishing including app details
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-App.ps1` (should use default paths from config)
- Run `.\scripts\Publish-App.ps1 -AppPath ".\build\output\app.app"` (should override config)
- Script should publish the app to the container
- Verify successful output message
- Check app is published in container using BcContainerHelper
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 6 (Create App Compilation Script)

### 9. [ ] Create Test App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-TestApp.ps1' in the scripts folder that:
1. Takes parameters for compiled test app file path (.app file) and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Uses BcContainerHelper to publish the test app to the container
5. Verifies the main app is published first (dependency handling)
6. Applies publishing settings from the configuration (scope, sync mode, timeout)
7. Handles errors gracefully with clear error messages
8. Provides feedback on successful publishing including app details
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-TestApp.ps1` (should use default paths from config)
- Run `.\scripts\Publish-TestApp.ps1 -TestAppPath ".\build\output\testapp.app"` (should override config)
- Script should publish the test app to the container
- Verify successful output message
- Check test app is published in container using BcContainerHelper
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 7 (Create Test App Compilation Script)
- Task 8 (Create App Publishing Script)

### 10. [ ] Create Combined App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-Apps.ps1' in the scripts folder that:
1. Takes parameters for compiled app file path, compiled test app file path, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Has switches to control which apps to publish (app only, test only, or both)
5. Applies publishing settings from the configuration (scope, sync mode, timeout)
6. Calls the individual publish scripts with appropriate parameters
7. Handles proper sequencing (main app before test app)
8. Provides consolidated feedback on the publishing process
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-Apps.ps1 -PublishApp -PublishTestApp` (should use default paths from config)
- Run `.\scripts\Publish-Apps.ps1 -AppPath ".\build\output\app.app" -TestAppPath ".\build\output\testapp.app" -PublishApp -PublishTestApp` (should override config)
- Script should publish both apps to the container
- Run `.\scripts\Publish-Apps.ps1 -PublishApp` (should only publish main app)
- Run `.\scripts\Publish-Apps.ps1 -PublishTestApp` (should only publish test app)
- Verify appropriate output messages for each scenario
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 8 (Create App Publishing Script)
- Task 9 (Create Test App Publishing Script)

## Test Execution

### 11. [ ] Create Test Runner Script

**Prompt:**
```
Create a PowerShell script named 'Run-Tests.ps1' in the scripts folder that:
1. Takes parameters for container name, test codeunit ID/name, and result file path with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Uses BcContainerHelper to run the specified tests in the container
5. Applies test settings from the configuration (timeout, fail behavior)
6. Captures test results and formats them for easy reading
7. Supports running all tests or specific test codeunits
8. Returns appropriate exit code based on test success/failure
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Run-Tests.ps1` (should run all tests using config defaults)
- Run `.\scripts\Run-Tests.ps1 -TestCodeunit "HelloWorld Test"` (should run specific test)
- Verify test results are displayed correctly
- Check exit code is 0 for success and non-zero for failure
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 9 (Create Test App Publishing Script)
- Task 10 (Create Combined App Publishing Script)

### 12. [ ] Create Test Results Viewer Script

**Prompt:**
```
Create a PowerShell script named 'View-TestResults.ps1' in the scripts folder that:
1. Takes a parameter for the test results file path with default from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Formats and displays test results in a readable format
5. Applies TDD session settings from the configuration (detail level, show passed tests)
6. Provides summary statistics (tests run, passed, failed)
7. Highlights failed tests with details on why they failed
Include parameter validation and help information.
```

**Verification:**
- Run tests with `.\scripts\Run-Tests.ps1` (should use default result file path from config)
- Run `.\scripts\View-TestResults.ps1` (should use default result file path from config)
- Run `.\scripts\View-TestResults.ps1 -ResultFile "TestResults.xml"` (should override config)
- Verify results are displayed in a readable format
- Check summary statistics are accurate
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 11 (Create Test Runner Script)

## TDD Workflow Integration

### 13. [ ] Create TDD Session Script

**Prompt:**
```
Create a PowerShell script named 'Start-TDDSession.ps1' in the scripts folder that:
1. Uses Get-TDDConfiguration.ps1 to load configuration settings
2. Uses Common-Functions.ps1 for utility functions
3. Initializes the environment by calling Initialize-TDDEnvironment.ps1
4. Provides a menu-driven interface for the TDD workflow with options to:
   - Prepare app source
   - Compile app
   - Prepare test app source
   - Compile test app
   - Publish app
   - Publish test app
   - Run all tests
   - Run specific tests
   - View test results
   - Edit configuration settings
   - Exit the session
5. Applies TDD session settings from the configuration (remember last run, auto-save results)
6. Maintains state between commands according to configuration
7. Provides clear feedback after each action
Include detailed help information and usage examples.
```

**Verification:**
- Run `.\scripts\Start-TDDSession.ps1`
- Navigate through menu options and verify each works correctly
- Verify state is maintained between commands according to configuration
- Test editing configuration settings through the menu
- Check feedback is clear and helpful
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 5 (Create App Source Preparation Script)
- Task 6 (Create App Compilation Script)
- Task 7 (Create Test App Compilation Script)
- Task 10 (Create Combined App Publishing Script)
- Task 11 (Create Test Runner Script)
- Task 12 (Create Test Results Viewer Script)

### 14. [ ] Create Watch Mode Script

**Prompt:**
```
Create a PowerShell script named 'Watch-Changes.ps1' in the scripts folder that:
1. Takes parameters for app path, test app path, and container name with defaults from configuration
2. Uses Get-TDDConfiguration.ps1 to load configuration settings
3. Uses Common-Functions.ps1 for utility functions
4. Applies watch mode settings from the configuration (interval, auto-publish, auto-run tests)
5. Watches for changes in the specified directories
6. When changes are detected, automatically:
   - Prepares the source files
   - Compiles the changed app(s)
   - Publishes the changed app(s)
   - Runs the tests
   - Displays the results
7. Continues watching until manually stopped
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Watch-Changes.ps1` (should use default paths from config)
- Run `.\scripts\Watch-Changes.ps1 -AppPath ".\app" -TestAppPath ".\test"` (should override config)
- Make a change to a file in the app directory
- Verify app is automatically prepared, compiled, published, and tests are run
- Make a change to a file in the test directory
- Verify test app is automatically prepared, compiled, published, and tests are run
- Check results are displayed correctly
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 4.9 (Create Script Template Using Common-Functions.ps1)
- Task 5 (Create App Source Preparation Script)
- Task 6 (Create App Compilation Script)
- Task 7 (Create Test App Compilation Script)
- Task 10 (Create Combined App Publishing Script)
- Task 11 (Create Test Runner Script)
- Task 12 (Create Test Results Viewer Script)

## Documentation

### 15. [ ] Create Workflow Documentation

**Prompt:**
```
Create a markdown file named 'TDD-Workflow.md' in the root directory that:
1. Explains the TDD workflow for Business Central
2. Provides detailed instructions for using each script
3. Includes examples for common scenarios
4. Explains how to customize the workflow for specific needs
5. Includes troubleshooting information for common issues
The documentation should be comprehensive but easy to follow.
```

**Verification:**
- Review `TDD-Workflow.md` for completeness and accuracy
- Verify all scripts are documented with examples
- Check troubleshooting section covers common issues

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 14 (All script creation tasks)

### 16. [ ] Update README.md

**Prompt:**
```
Update the README.md file in the root directory to:
1. Add a section about the TDD workflow
2. Provide a brief overview of the available scripts
3. Link to the detailed TDD-Workflow.md documentation
4. Include a quick start guide for getting started with TDD
The updates should integrate well with the existing README content.
```

**Verification:**
- Review updated README.md
- Verify TDD workflow section is added
- Check links to documentation work correctly
- Ensure quick start guide is clear and concise

**Dependencies:**
- Task 15 (Create Workflow Documentation)

## Testing and Refinement

### 17. [ ] Create Example Test and Implementation

**Prompt:**
```
Create an example test and implementation to demonstrate the TDD workflow:
1. Create a test codeunit in the test app that tests a new feature
2. Create the implementation in the main app that makes the test pass
3. Document the example in a markdown file named 'TDD-Example.md' in the .aiwork directory
The example should be simple but illustrative of the TDD process.
```

**Verification:**
- Review the test and implementation code
- Follow the TDD workflow with the example
- Verify tests fail initially and pass after implementation
- Check documentation clearly explains the example

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 14 (All script creation tasks)

### 18. [ ] Perform End-to-End Workflow Test

**Prompt:**
```
Perform an end-to-end test of the TDD workflow and document the results:
1. Verify and update the scripts\TDDConfig.psd1 file with appropriate settings
2. Start with the Initialize-TDDEnvironment.ps1 script
3. Prepare app source using Prepare-AppSource.ps1
4. Compile the main app using Compile-App.ps1
5. Prepare test app source using Prepare-AppSource.ps1
6. Compile the test app using Compile-TestApp.ps1
7. Publish the main app using Publish-App.ps1
8. Publish the test app using Publish-TestApp.ps1 (or use Publish-Apps.ps1 for both)
9. Run tests using Run-Tests.ps1
10. View results using View-TestResults.ps1
11. Make a change to the test app that causes a test to fail
12. Recompile and republish the test app
13. Run tests to verify failure
14. Make a change to the main app to fix the test
15. Recompile and republish the main app
16. Run tests to verify success
17. Try the Start-TDDSession.ps1 script for an interactive workflow
18. Test the Watch-Changes.ps1 script for automatic workflow
19. Document any issues or improvements needed
```

**Verification:**
- Complete the end-to-end workflow
- Verify each step works as expected
- Document any issues or improvements needed
- Make necessary script adjustments

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 14 (All script creation tasks)
- Task 17 (Create Example Test and Implementation)

### 19. [ ] Refine Scripts Based on Testing

**Prompt:**
```
Refine the scripts based on the end-to-end testing:
1. Address any issues identified during testing
2. Improve error handling and feedback
3. Optimize performance where possible
4. Ensure consistent parameter naming and behavior across scripts
5. Update documentation to reflect any changes
```

**Verification:**
- Review and test all script changes
- Verify issues are resolved
- Check documentation is updated
- Perform another end-to-end test to confirm improvements

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.5 through 4.9 (Refactoring scripts to use Common-Functions.ps1)
- Task 5 through 14 (All script creation tasks)
- Task 18 (Perform End-to-End Workflow Test)

## Final Integration

### 20. [ ] Create Master Script

**Prompt:**
```
Create a master script named 'TDD-Workflow.ps1' in the scripts folder that:
1. Uses Get-TDDConfiguration.ps1 to load configuration settings
2. Uses Common-Functions.ps1 for utility functions
3. Provides a single entry point for all TDD workflow functions
4. Includes command-line parameters for all major functions with defaults from configuration
5. Supports both interactive and non-interactive modes
6. Can be used in CI/CD pipelines
7. Allows overriding configuration settings via parameters
8. Includes comprehensive help information
This should be a unified interface for the entire TDD workflow.
```

**Verification:**
- Run `.\scripts\TDD-Workflow.ps1 -Help` to view help information
- Test various command-line parameters
- Verify both interactive and non-interactive modes work
- Check script can be used in a CI/CD context
- Confirm the script uses the centralized configuration management

**Dependencies:**
- Task 4.4 (Create Common Functions Script)
- Task 4.8 (Refactor Get-TDDConfiguration.ps1 to Use Common-Functions.ps1)
- Task 5 through 14 (All script creation tasks)
- Task 19 (Refine Scripts Based on Testing)

### 21. [ ] Final Documentation Update

**Prompt:**
```
Update all documentation to reflect the final state of the TDD workflow:
1. Update TDD-Workflow.md with final script details
2. Update README.md with any additional information
3. Create a quick reference card as TDD-QuickRef.md in the .aiwork directory
4. Create a configuration guide as TDD-Configuration.md explaining all settings in scripts\TDDConfig.psd1
5. Ensure all examples and instructions are accurate
6. Include information about customizing the workflow through configuration settings
```

**Verification:**
- Review all documentation for accuracy and completeness
- Verify quick reference card covers all essential commands
- Check configuration guide explains all settings clearly
- Test examples work as described
- Ensure documentation is user-friendly and explains how to customize the workflow

**Dependencies:**
- Task 15 (Create Workflow Documentation)
- Task 16 (Update README.md)
- Task 19 (Refine Scripts Based on Testing)
- Task 20 (Create Master Script)
