codeunit 50003 "Test Codeunit 50003"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";

    [Test]
    procedure TestModuloOperationWorks()
    var
        Result: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Performing modulo operation
        Result := 17 mod 5;

        // [THEN] The result should be correct
        TestLibrary.AssertEquals(2, Result, 'Modulo operation 17 mod 5 should equal 2');
    end;

    [Test]
    procedure TestStringUpperCaseConversion()
    var
        OriginalText: Text[50];
        UpperText: Text[50];
    begin
        // [GIVEN] A clean test environment and a lowercase string
        Initialize();
        OriginalText := 'business central';

        // [WHEN] Converting to uppercase
        UpperText := UpperCase(OriginalText);

        // [THEN] The result should be correct
        TestLibrary.AssertEquals('BUSINESS CENTRAL', UpperText, 'Uppercase conversion should work correctly');
    end;

    [Test]
    procedure TestNumberComparisonIsCorrect()
    var
        Number1: Integer;
        Number2: Integer;
        IsGreater: Boolean;
    begin
        // [GIVEN] A clean test environment and two numbers
        Initialize();
        Number1 := 15;
        Number2 := 10;

        // [WHEN] Comparing the numbers
        IsGreater := Number1 > Number2;

        // [THEN] The comparison should be correct
        TestLibrary.AssertTrue(IsGreater, '15 should be greater than 10');
    end;

    [Test]
    procedure TestEqualityComparisonFails()
    var
        Value1: Integer;
        Value2: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        Value1 := 5;
        Value2 := 5;

        // [WHEN] Comparing equal values
        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertEquals(7, Value1, 'Value 5 should equal 7 (intentional failure)');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
    end;
}
