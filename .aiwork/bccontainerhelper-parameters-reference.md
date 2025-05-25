# BcContainerHelper Run-TestsInBcContainer Parameter Reference

## Overview

This document provides detailed information about the `Run-TestsInBcContainer` cmdlet parameters, specifically focusing on the parameters relevant to the TDD workflow implementation.

## Key Parameters for TDD Workflow

### extensionId (Position 14)
- **Type**: String
- **Required**: false
- **Default**: Empty string
- **Description**: Specifying an extensionId causes the test tool to run all tests in the app with this app id.
- **Usage**: Used to run tests for a specific extension/app

### testCodeunitRange (Position 12)
- **Type**: String  
- **Required**: false
- **Default**: Empty string
- **Description**: A BC-compatible filter string to use for loading test codeunits (similar to -extensionId). This is not to be confused with -testCodeunit.
- **Usage**: If you set this parameter to '*', all test codeunits will be loaded.
- **Note**: This might not work on all versions of BC and only works when using the command-line-testtool.

### testCodeunit (Position 11)
- **Type**: String
- **Required**: false
- **Default**: "*"
- **Description**: Name or ID of test codeunit to run. Wildcards (? and *) are supported. This parameter will not populate the test suite with the specified codeunit. This is used as a filter on the tests that are already present (or otherwise loaded) in the suite.
- **Note**: This is not to be confused with -testCodeunitRange.

### testFunction (Position 13)
- **Type**: String
- **Required**: false
- **Default**: "*"
- **Description**: Name of test function to run. Wildcards (? and *) are supported.

### testSuite (Position 9)
- **Type**: String
- **Required**: false
- **Default**: "DEFAULT"
- **Description**: Name of test suite to run.

## Parameter Compatibility Rules

### When using extensionId:
Based on the current implementation in `Run-Tests.ps1` and BcContainerHelper behavior:

1. **extensionId** and **testCodeunit** are mutually exclusive
   - When `extensionId` is specified, `testCodeunit` should be removed from parameters
   - The extension ID loads all tests from the specified app

2. **extensionId** and **testFunction** are mutually exclusive  
   - When `extensionId` is specified, `testFunction` should be removed from parameters
   - The extension ID runs all test functions in the app

3. **testCodeunitRange** can be used independently
   - `testCodeunitRange` is a separate parameter for loading test codeunits
   - It's not mutually exclusive with `extensionId` but serves a different purpose
   - `testCodeunitRange` loads test codeunits, while `extensionId` runs tests from a specific app

### Parameter Priority Logic:
1. If `extensionId` is provided → Remove `testCodeunit` and `testFunction`
2. If `testCodeunitRange` is provided → Use it for loading test codeunits
3. Default behavior → Use `testCodeunit` and `testFunction` filters

## Implementation Notes

### For Run-Tests.ps1 Modifications:
1. **testCodeunitRange** parameter should be added as optional
2. **extensionId** should be dynamically read from `test\app.json` when not provided
3. Existing mutual exclusivity logic for `extensionId` should be maintained
4. **testCodeunitRange** should be passed through when provided

### Verification Criteria Met:
- ✅ Confirmed exact parameter name: `testCodeunitRange` (not `testRange`)
- ✅ Verified parameter compatibility when `extensionId` is used
- ✅ Documented mutual exclusivity rules for parameters  
- ✅ Created reference documentation for parameter usage

## Additional Parameters of Interest

### XUnitResultFileName (Position 18)
- **Type**: String
- **Description**: Filename where the function should place an XUnit compatible result file
- **Usage**: Used for test result output in TDD workflow

### returnTrueIfAllPassed
- **Type**: SwitchParameter
- **Description**: Specify this switch if the function should return true/false on whether all tests passes
- **Usage**: Used for determining test success/failure in scripts

### detailed
- **Type**: SwitchParameter  
- **Description**: Include this switch to output success/failure information for all tests
- **Usage**: Provides more detailed test output

## Source Information

This documentation is based on:
- BcContainerHelper module help output (`Get-Help Run-TestsInBcContainer -Full`)
- Current implementation in `scripts\workflow\Run-Tests.ps1`
- Analysis of parameter behavior and mutual exclusivity rules
