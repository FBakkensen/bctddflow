codeunit 50005 "Test Codeunit 50005"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";

    [Test]
    procedure TestMaximumValueIsCorrect()
    var
        Value1: Integer;
        Value2: Integer;
        MaxValue: Integer;
    begin
        // [GIVEN] A clean test environment and two values
        Initialize();
        Value1 := 42;
        Value2 := 37;

        // [WHEN] Finding the maximum value
        if Value1 > Value2 then
            MaxValue := Value1
        else
            MaxValue := Value2;

        // [THEN] The result should be correct
        TestLibrary.AssertEquals(42, MaxValue, 'Maximum of 42 and 37 should be 42');
    end;

    [Test]
    procedure TestStringTrimWorks()
    var
        StringWithSpaces: Text[100];
        TrimmedString: Text[100];
    begin
        // [GIVEN] A clean test environment and a string with spaces
        Initialize();
        StringWithSpaces := '  Business Central  ';

        // [WHEN] Trimming the string
        TrimmedString := DelChr(StringWithSpaces, '<>', ' ');

        // [THEN] The result should be trimmed
        TestLibrary.AssertEquals('Business Central', TrimmedString, 'String should be trimmed correctly');
    end;

    [Test]
    procedure TestRoundingOperationFails()
    var
        DecimalValue: Decimal;
        RoundedValue: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        DecimalValue := 3.7;

        // [WHEN] Rounding the decimal value
        RoundedValue := Round(DecimalValue, 1);

        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertEquals(3, RoundedValue, 'Rounded value of 3.7 should be 3 (intentional failure)');
    end;

    [Test]
    procedure TestMinimumValueFails()
    var
        Value1: Integer;
        Value2: Integer;
        MinValue: Integer;
    begin
        // [GIVEN] A clean test environment and two values
        Initialize();
        Value1 := 15;
        Value2 := 20;

        // [WHEN] Finding the minimum value
        if Value1 < Value2 then
            MinValue := Value1
        else
            MinValue := Value2;

        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertEquals(20, MinValue, 'Minimum of 15 and 20 should be 20 (intentional failure)');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
    end;
}
