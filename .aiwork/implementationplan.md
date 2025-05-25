# Implementation Plan: Modify Run-Tests.ps1 for Dynamic Extension ID and Optional Parameters

## Overview

This plan outlines the steps needed to modify the `Run-Tests.ps1` script to meet the following requirements:
- **MUST include** `-extensionId` parameter dynamically read from `test\app.json`
- **MUST NOT include** `-testSuite` parameter (already compliant)
- **MUST support** optional `-testCodeunit` and `-testCodeunitRange` parameters
- **Do not hardcode** the extension ID value

## Implementation Tasks

### Task 1: Research BcContainerHelper Parameters
**Status:** [x]

**Prompt:** Research the BcContainerHelper module's `Run-TestsInBcContainer` cmdlet to verify the exact parameter names and compatibility rules. Specifically check if `testCodeunitRange` is a valid parameter and confirm which parameters are mutually exclusive with `extensionId`.

**Verification Criteria:**
- [x] Confirmed exact parameter name for test codeunit range (e.g., `testCodeunitRange`, `testRange`, etc.)
- [x] Verified parameter compatibility when `extensionId` is used
- [x] Documented mutual exclusivity rules for parameters
- [x] Created reference documentation for parameter usage

### Task 2: Add TestCodeunitRange Parameter to Run-Tests.ps1
**Status:** [x]

**Prompt:** Add the `TestCodeunitRange` parameter to the `scripts\workflow\Run-Tests.ps1` script. Update both the script-level parameters section and the `Invoke-RunTest` function parameters. Include proper parameter documentation and help text.

**Verification Criteria:**
- [x] `TestCodeunitRange` parameter added to script parameters with `[Parameter(Mandatory = $false)]`
- [x] Parameter added to `Invoke-RunTest` function with default empty string value
- [x] Parameter documentation updated in script header `.PARAMETER` section
- [x] Help text includes description of the new parameter
- [x] PSScriptAnalyzer shows no errors for the parameter definition

### Task 3: Create JSON Reading Helper Function
**Status:** [x]

**Prompt:** Create a helper function `Get-ExtensionIdFromAppJson` in the `Run-Tests.ps1` script that reads and parses the test application's `app.json` file to extract the extension ID. The function should use the centralized configuration from `scripts\TDDConfig.psd1` to locate the test app.json file by reading the `SourcePaths.Test` configuration value instead of using hardcoded paths. Include robust error handling for file not found, invalid JSON, and missing ID field scenarios.

**Verification Criteria:**
- [x] Function `Get-ExtensionIdFromAppJson` created with proper parameter validation
- [x] Function accepts a configuration parameter to access `SourcePaths.Test` value
- [x] Function constructs the path to app.json using `$Config.SourcePaths.Test` from configuration
- [x] Function uses `Resolve-TDDPath` from Common-Functions.ps1 for proper path resolution
- [x] Function uses `Get-Content` and `ConvertFrom-Json` to parse the file
- [x] Error handling implemented for file not found scenarios
- [x] Error handling implemented for invalid JSON format
- [x] Error handling implemented for missing `id` field in JSON
- [x] Function returns the extension ID as a string
- [x] Function includes proper documentation with `.SYNOPSIS` and `.DESCRIPTION`
- [x] No hardcoded paths to test directory or app.json file

### Task 4: Implement Extension ID Resolution Logic
**Status:** [ ]

**Prompt:** Modify the extension ID handling logic in `Run-Tests.ps1` to implement the following priority: 1) Use ExtensionId parameter if provided, 2) Read from `test\app.json` if parameter is empty, 3) Throw error if both fail. Use `Resolve-TDDPath` from Common-Functions.ps1 for path resolution.

**Verification Criteria:**
- [ ] Logic checks if `ExtensionId` parameter is provided and non-empty first
- [ ] If parameter empty, constructs path to `test\app.json` using `Resolve-TDDPath` and config
- [ ] Calls `Get-ExtensionIdFromAppJson` function to read from JSON file
- [ ] Throws descriptive error if both parameter and JSON file fail
- [ ] Logs informational messages about extension ID source
- [ ] Extension ID is stored in a variable for later use
- [ ] Path resolution uses `$Config.SourcePaths.Test` from configuration

### Task 5: Update Run-TestsInBcContainer Parameter Handling
**Status:** [ ]

**Prompt:** Update the parameter handling logic for `Run-TestsInBcContainer` in `Run-Tests.ps1` to always include the `extensionId` parameter (now required) and add support for the optional `testCodeunitRange` parameter. Maintain existing logic for removing `testCodeunit` and `testFunction` when `extensionId` is used.

**Verification Criteria:**
- [ ] `extensionId` parameter is always added to `$testParams` hashtable
- [ ] `testCodeunitRange` parameter added when provided and non-empty
- [ ] Existing logic maintained for removing `testCodeunit` when `extensionId` is used
- [ ] Existing logic maintained for removing `testFunction` when `extensionId` is used
- [ ] Parameter logging updated to show `testCodeunitRange` when used
- [ ] Extension ID logging shows the resolved value and source
- [ ] Error thrown if extension ID cannot be determined

### Task 6: Update Start-TDDWorkflow.ps1 Parameter Support
**Status:** [ ]

**Prompt:** Evaluate and update `scripts\Start-TDDWorkflow.ps1` to support the new `TestCodeunitRange` parameter. Add the parameter to the script if needed and ensure it's properly passed to `Run-Tests.ps1`.

**Verification Criteria:**
- [ ] Evaluated whether `TestCodeunitRange` parameter should be added to Start-TDDWorkflow.ps1
- [ ] If needed, parameter added with proper validation and documentation
- [ ] Parameter properly passed to Run-Tests.ps1 in the `$runTestsParams` hashtable
- [ ] Script help documentation updated if parameter was added
- [ ] No breaking changes to existing parameter handling

### Task 7: Update TDD-Workflow.md Documentation
**Status:** [ ]

**Prompt:** Update the `TDD-Workflow.md` file to document the new parameter behavior for `Run-Tests.ps1`. Include information about automatic extension ID reading from `test\app.json`, the new `TestCodeunitRange` parameter, and updated usage examples.

**Verification Criteria:**
- [ ] Run-Tests.ps1 parameter documentation updated with `TestCodeunitRange`
- [ ] Documentation explains automatic extension ID reading behavior
- [ ] Usage examples updated to show new parameter options
- [ ] Examples demonstrate both explicit ExtensionId and automatic reading scenarios
- [ ] Documentation maintains consistent formatting and style
- [ ] All parameter descriptions are accurate and complete

### Task 8: Comprehensive Testing and Validation
**Status:** [ ]

**Prompt:** Perform comprehensive testing of the modified `Run-Tests.ps1` script to ensure backward compatibility, proper extension ID resolution, new parameter functionality, and error handling. Run PSScriptAnalyzer to ensure code quality compliance.

**Verification Criteria:**
- [ ] Existing calls to Run-Tests.ps1 without ExtensionId parameter work correctly
- [ ] Extension ID is automatically read from `test\app.json` when parameter not provided
- [ ] ExtensionId parameter still works when explicitly provided
- [ ] TestCodeunitRange parameter functions correctly when provided
- [ ] Error handling works for missing `test\app.json` file
- [ ] Error handling works for invalid JSON in `test\app.json`
- [ ] Error handling works for missing `id` field in JSON
- [ ] PSScriptAnalyzer reports no errors or warnings
- [ ] Integration with Start-TDDWorkflow.ps1 works correctly
- [ ] All logging messages are clear and informative

## Success Criteria

The implementation will be considered complete when:
- ✅ ExtensionId is dynamically read from `test\app.json` when not provided as parameter
- ✅ TestCodeunitRange parameter is supported and optional
- ✅ No testSuite parameter is used (already compliant)
- ✅ Extension ID value is never hardcoded
- ✅ Backward compatibility is maintained with existing scripts
- ✅ Proper error handling for all scenarios
- ✅ PSScriptAnalyzer compliance achieved
- ✅ Documentation is updated and accurate
- ✅ Integration with existing TDD workflow maintained

## Files Modified

1. `scripts\workflow\Run-Tests.ps1` - Primary implementation
2. `scripts\Start-TDDWorkflow.ps1` - Parameter support (if needed)
3. `TDD-Workflow.md` - Documentation updates

## Configuration Dependencies

- Uses existing `TDDConfig.psd1` configuration for path resolution
- Leverages `Common-Functions.ps1` for `Resolve-TDDPath` functionality
- Maintains integration with centralized configuration management
