# Business Central TDD Workflow Implementation Plan

This document outlines the step-by-step implementation plan for creating a Test-Driven Development (TDD) workflow for Business Central using Docker. Each task is designed to be atomic and builds upon previous tasks to create a complete workflow.

## Environment Setup

### 1. [ ] Create Environment Verification Script

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

### 2. [ ] Create Environment Setup Script

**Prompt:**
```
Create a PowerShell script named 'Initialize-TDDEnvironment.ps1' in the scripts folder that:
1. Calls Verify-Environment.ps1 to ensure prerequisites are met
2. If the 'bctest' container doesn't exist, creates it with appropriate settings
3. If the container exists but isn't running, starts it
4. Sets up any necessary environment variables for the TDD workflow
Include detailed comments explaining each step and any parameters that can be customized.
```

**Verification:**
- Run `.\scripts\Initialize-TDDEnvironment.ps1`
- Script should check environment and start the container if needed
- Verify container is running with `docker ps`
- Script should output success message with container details

## App Management

### 3. [ ] Create App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-App.ps1' in the scripts folder that:
1. Takes parameters for app path and container name (default to 'bctest')
2. Uses BcContainerHelper to publish the specified app to the container
3. Handles errors gracefully with clear error messages
4. Provides feedback on successful publishing
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-App.ps1 -AppPath ".\app"`
- Script should publish the app to the container
- Verify successful output message
- Check app is published in container using BcContainerHelper

### 4. [ ] Create Test App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-TestApp.ps1' in the scripts folder that:
1. Takes parameters for test app path and container name (default to 'bctest')
2. Uses BcContainerHelper to publish the test app to the container
3. Ensures the main app is published first (dependency handling)
4. Handles errors gracefully with clear error messages
5. Provides feedback on successful publishing
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-TestApp.ps1 -TestAppPath ".\test"`
- Script should publish the test app to the container
- Verify successful output message
- Check test app is published in container using BcContainerHelper

### 5. [ ] Create Combined App Publishing Script

**Prompt:**
```
Create a PowerShell script named 'Publish-Apps.ps1' in the scripts folder that:
1. Takes parameters for app path, test app path, and container name (with appropriate defaults)
2. Has switches to control which apps to publish (app only, test only, or both)
3. Calls the individual publish scripts with appropriate parameters
4. Provides consolidated feedback on the publishing process
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Publish-Apps.ps1 -PublishApp -PublishTestApp`
- Script should publish both apps to the container
- Run `.\scripts\Publish-Apps.ps1 -PublishApp` (should only publish main app)
- Run `.\scripts\Publish-Apps.ps1 -PublishTestApp` (should only publish test app)
- Verify appropriate output messages for each scenario

## Test Execution

### 6. [ ] Create Test Runner Script

**Prompt:**
```
Create a PowerShell script named 'Run-Tests.ps1' in the scripts folder that:
1. Takes parameters for container name, test codeunit ID/name, and result file path
2. Uses BcContainerHelper to run the specified tests in the container
3. Captures test results and formats them for easy reading
4. Supports running all tests or specific test codeunits
5. Returns appropriate exit code based on test success/failure
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Run-Tests.ps1` (should run all tests)
- Run `.\scripts\Run-Tests.ps1 -TestCodeunit "HelloWorld Test"` (should run specific test)
- Verify test results are displayed correctly
- Check exit code is 0 for success and non-zero for failure

### 7. [ ] Create Test Results Viewer Script

**Prompt:**
```
Create a PowerShell script named 'View-TestResults.ps1' in the scripts folder that:
1. Takes a parameter for the test results file path
2. Formats and displays test results in a readable format
3. Provides summary statistics (tests run, passed, failed)
4. Highlights failed tests with details on why they failed
Include parameter validation and help information.
```

**Verification:**
- Run tests with `.\scripts\Run-Tests.ps1 -ResultFile "TestResults.xml"`
- Run `.\scripts\View-TestResults.ps1 -ResultFile "TestResults.xml"`
- Verify results are displayed in a readable format
- Check summary statistics are accurate

## TDD Workflow Integration

### 8. [ ] Create TDD Session Script

**Prompt:**
```
Create a PowerShell script named 'Start-TDDSession.ps1' in the scripts folder that:
1. Initializes the environment by calling Initialize-TDDEnvironment.ps1
2. Provides a menu-driven interface for the TDD workflow with options to:
   - Publish app
   - Publish test app
   - Run all tests
   - Run specific tests
   - View test results
   - Exit the session
3. Maintains state between commands (remembers last test run, etc.)
4. Provides clear feedback after each action
Include detailed help information and usage examples.
```

**Verification:**
- Run `.\scripts\Start-TDDSession.ps1`
- Navigate through menu options and verify each works correctly
- Verify state is maintained between commands
- Check feedback is clear and helpful

### 9. [ ] Create Watch Mode Script

**Prompt:**
```
Create a PowerShell script named 'Watch-Changes.ps1' in the scripts folder that:
1. Takes parameters for app path, test app path, and container name
2. Watches for changes in the specified directories
3. When changes are detected, automatically:
   - Publishes the changed app(s)
   - Runs the tests
   - Displays the results
4. Continues watching until manually stopped
Include parameter validation and help information.
```

**Verification:**
- Run `.\scripts\Watch-Changes.ps1`
- Make a change to a file in the app directory
- Verify app is automatically published and tests are run
- Make a change to a file in the test directory
- Verify test app is automatically published and tests are run
- Check results are displayed correctly

## Documentation

### 10. [ ] Create Workflow Documentation

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

### 11. [ ] Update README.md

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

## Testing and Refinement

### 12. [ ] Create Example Test and Implementation

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

### 13. [ ] Perform End-to-End Workflow Test

**Prompt:**
```
Perform an end-to-end test of the TDD workflow and document the results:
1. Start with the Initialize-TDDEnvironment.ps1 script
2. Publish both apps using Publish-Apps.ps1
3. Run tests using Run-Tests.ps1
4. View results using View-TestResults.ps1
5. Make a change to the test app that causes a test to fail
6. Run tests to verify failure
7. Make a change to the main app to fix the test
8. Run tests to verify success
9. Document any issues or improvements needed
```

**Verification:**
- Complete the end-to-end workflow
- Verify each step works as expected
- Document any issues or improvements needed
- Make necessary script adjustments

### 14. [ ] Refine Scripts Based on Testing

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

## Final Integration

### 15. [ ] Create Master Script

**Prompt:**
```
Create a master script named 'TDD-Workflow.ps1' in the scripts folder that:
1. Provides a single entry point for all TDD workflow functions
2. Includes command-line parameters for all major functions
3. Supports both interactive and non-interactive modes
4. Can be used in CI/CD pipelines
5. Includes comprehensive help information
This should be a unified interface for the entire TDD workflow.
```

**Verification:**
- Run `.\scripts\TDD-Workflow.ps1 -Help` to view help information
- Test various command-line parameters
- Verify both interactive and non-interactive modes work
- Check script can be used in a CI/CD context

### 16. [ ] Final Documentation Update

**Prompt:**
```
Update all documentation to reflect the final state of the TDD workflow:
1. Update TDD-Workflow.md with final script details
2. Update README.md with any additional information
3. Create a quick reference card as TDD-QuickRef.md in the .aiwork directory
4. Ensure all examples and instructions are accurate
```

**Verification:**
- Review all documentation for accuracy and completeness
- Verify quick reference card covers all essential commands
- Check examples work as described
- Ensure documentation is user-friendly