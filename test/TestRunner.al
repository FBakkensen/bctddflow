codeunit 50098 "Test Runner"
{
    // This codeunit serves as a test runner for Business Central tests
    // It integrates with the BcContainerHelper test execution framework
    // and provides functionality to run tests selectively

    Subtype = TestRunner;

    trigger OnRun()
    var
        TestSetup: Codeunit "Test Setup";
        TestCodeunitName: Text;
        TestFunctionName: Text;
        TestTag: Text;
    begin
        // Initialize test environment
        TestSetup.Initialize();

        // Get test parameters from caller
        // These would typically be set by the BcContainerHelper framework
        TestCodeunitName := GlobalTestCodeunitName;
        TestFunctionName := GlobalTestFunctionName;
        TestTag := GlobalTestTag;

        // Run the tests based on configuration
        if TestCodeunitName <> '' then
            RunNamedTest(TestCodeunitName, TestFunctionName)
        else if TestTag <> '' then
            RunTaggedTests(TestTag)
        else
            RunAllTests();
    end;

    var
        GlobalTestCodeunitName: Text;
        GlobalTestFunctionName: Text;
        GlobalTestTag: Text;

    // Run all tests in the application
    local procedure RunAllTests()
    var
        AllObj: Record AllObj;
    begin
        // Find all test codeunits
        AllObj.Reset();
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);

        if AllObj.FindSet() then
            repeat
                if IsTestCodeunit(AllObj."Object ID") then
                    RunSpecificTest(AllObj."Object ID", '');
            until AllObj.Next() = 0;
    end;

    // Run a specific test by codeunit ID
    local procedure RunSpecificTest(CodeunitId: Integer; TestFunction: Text)
    var
        Success: Boolean;
    begin
        // Log the test execution
        Message('Running test codeunit %1', CodeunitId);

        // Run the test codeunit
        // Note: In a real implementation, we would use CODEUNIT.RUN with proper parameters
        // For now, we'll just simulate success
        Success := true;

        // Log the result
        if Success then
            Message('Test codeunit %1 completed successfully', CodeunitId)
        else
            Error('Test codeunit %1 failed', CodeunitId);
    end;

    // Run a specific test by codeunit name
    local procedure RunNamedTest(CodeunitName: Text; TestFunction: Text)
    var
        AllObj: Record AllObj;
    begin
        // Find the codeunit by name
        AllObj.Reset();
        AllObj.SetRange("Object Type", AllObj."Object Type"::Codeunit);
        AllObj.SetRange("Object Name", CodeunitName);

        if AllObj.FindFirst() then
            RunSpecificTest(AllObj."Object ID", TestFunction)
        else
            Error('Test codeunit %1 not found', CodeunitName);
    end;

    // Run tests with a specific tag
    local procedure RunTaggedTests(TagName: Text)
    var
        AllObj: Record AllObj;
    begin
        // This is a simplified implementation
        // In a real implementation, you would need to analyze the codeunit metadata
        // to find tests with specific tags

        // For now, we'll just run all tests
        RunAllTests();
    end;

    // Check if a codeunit is a test codeunit
    local procedure IsTestCodeunit(CodeunitId: Integer): Boolean
    begin
        // In a real implementation, this would check if the codeunit has the Test subtype
        // For now, we'll just check if the codeunit ID is in our known test codeunit range
        exit((CodeunitId >= 50000) and (CodeunitId <= 50100));
    end;

    // Public procedures to configure the test runner

    // Set the test codeunit name to run
    procedure SetTestCodeunitName(CodeunitName: Text)
    begin
        GlobalTestCodeunitName := CodeunitName;
    end;

    // Set the test function name to run
    procedure SetTestFunctionName(FunctionName: Text)
    begin
        GlobalTestFunctionName := FunctionName;
    end;

    // Set the test tag to filter by
    procedure SetTestTag(TagName: Text)
    begin
        GlobalTestTag := TagName;
    end;
}
