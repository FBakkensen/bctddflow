# Business Central Test Suite

This directory contains a comprehensive test suite for Business Central that organizes and groups test methods into a structured framework. The test suite follows Business Central best practices, includes proper test runner functionality, and integrates with the TDD workflow scripts to enable running tests selectively.

## Components

### 1. TestSuite.al (Codeunit 50100)

A core utility codeunit that provides common test functionality:
- Assertions (AssertTrue, AssertEquals, etc.)
- Test data creation (CreateTestCustomer, CreateTestItem)
- Random data generation (GetRandomInteger, GetRandomText, etc.)
- Sales document helpers (CreateSalesDocument, AddSalesLine, etc.)

### 2. TestRunner.al (Codeunit 50098)

A test runner codeunit that integrates with the BcContainerHelper test execution framework:
- Runs tests selectively based on codeunit name, function name, or tag
- Provides a standard interface for the TDD workflow scripts
- Logs test execution and results

### 3. TestSetup.al (Codeunit 50097)

A codeunit that handles common test setup and teardown operations:
- Initializes the test environment
- Sets up common test data
- Cleans up after tests
- Provides a consistent initialization pattern for all tests

### 4. TestLibrary.al (Codeunit 50099)

A codeunit that provides additional test utilities:
- Wraps TestSuite functionality for easy access
- Provides a clean API for test codeunits
- Centralizes test utility functions

### 5. HelloWorld.Test.al (Codeunit 50000)

An example test codeunit that demonstrates how to use the test framework:
- Shows proper test initialization
- Demonstrates message handler usage
- Includes test assertions
- Follows the Given-When-Then pattern for test clarity

## Usage

### Creating a New Test Codeunit

1. Create a new AL file with a codeunit that has the `Subtype = Test` property
2. Add the TestLibrary and TestSetup variables
3. Implement an Initialize method that calls TestSetup.Initialize()
4. Add test methods with the [Test] attribute
5. Follow the Given-When-Then pattern for test clarity

Example:

```al
codeunit 50001 "My Test"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";
        // Other variables

    [Test]
    procedure TestSomething()
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Some action is performed
        // ...

        // [THEN] Expected results are verified
        TestLibrary.AssertTrue(true, 'This should be true');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
        
        // Reset test-specific variables
        // ...
    end;
}
```

### Running Tests

Tests can be run using the TDD workflow scripts:

```powershell
# Run all tests
.\scripts\Run-Tests.ps1

# Run a specific test codeunit
.\scripts\Run-Tests.ps1 -TestCodeunit "My Test"

# Run a specific test function
.\scripts\Run-Tests.ps1 -TestCodeunit "My Test" -TestFunction "TestSomething"
```

## Integration with TDD Workflow

The test suite integrates with the TDD workflow scripts through the BcContainerHelper module:

1. The `Run-Tests.ps1` script uses the `Run-TestsInBcContainer` cmdlet from BcContainerHelper
2. Test results are captured and formatted as XUnit output
3. The test runner provides a consistent interface for the TDD workflow scripts
4. Test execution can be filtered by codeunit, function, or tag

## Best Practices

1. **Follow the Given-When-Then pattern** for test clarity
2. **Initialize properly** using the TestSetup.Initialize() method
3. **Use assertions** from TestLibrary instead of direct ERROR calls
4. **Clean up after tests** to avoid side effects
5. **Use descriptive test names** that explain what is being tested
6. **Add comments** to clarify test steps and expectations
7. **Use message handlers** for testing UI interactions
8. **Keep tests independent** from each other
9. **Use TestPermissions attribute** to control permissions during tests
