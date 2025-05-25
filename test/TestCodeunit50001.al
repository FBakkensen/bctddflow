codeunit 50001 "Test Codeunit 50001"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";

    [Test]
    procedure TestAdditionReturnsCorrectSum()
    var
        Result: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Adding two positive numbers
        Result := 5 + 3;

        // [THEN] The result should be correct
        TestLibrary.AssertEquals(8, Result, 'Addition of 5 + 3 should equal 8');
    end;

    [Test]
    procedure TestStringConcatenationWorks()
    var
        FirstName: Text[50];
        LastName: Text[50];
        FullName: Text[100];
    begin
        // [GIVEN] A clean test environment and two strings
        Initialize();
        FirstName := 'John';
        LastName := 'Doe';

        // [WHEN] Concatenating the strings
        FullName := FirstName + ' ' + LastName;

        // [THEN] The result should be correct
        TestLibrary.AssertEquals('John Doe', FullName, 'String concatenation should work correctly');
    end;

    [Test]
    procedure TestBooleanLogicIsTrue()
    var
        Condition1: Boolean;
        Condition2: Boolean;
        Result: Boolean;
    begin
        // [GIVEN] A clean test environment and boolean conditions
        Initialize();
        Condition1 := true;
        Condition2 := true;

        // [WHEN] Performing AND operation
        Result := Condition1 and Condition2;

        // [THEN] The result should be true
        TestLibrary.AssertTrue(Result, 'True AND True should equal True');
    end;

    [Test]
    procedure TestDivisionByZeroFails()
    var
        Numerator: Integer;
        Denominator: Integer;
        Result: Decimal;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        Numerator := 10;
        Denominator := 2;

        // [WHEN] Dividing by a non-zero number
        Result := Numerator / Denominator;

        // [THEN] The result should be incorrect (intentional failure)
        TestLibrary.AssertEquals(10, Result, 'Division 10/2 should equal 10 (intentional failure)');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
    end;
}
