codeunit 50004 "Test Codeunit 50004"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";

    [Test]
    procedure TestAbsoluteValueIsCorrect()
    var
        NegativeNumber: Integer;
        AbsoluteValue: Integer;
    begin
        // [GIVEN] A clean test environment and a negative number
        Initialize();
        NegativeNumber := -25;

        // [WHEN] Getting the absolute value
        AbsoluteValue := Abs(NegativeNumber);

        // [THEN] The result should be positive
        TestLibrary.AssertEquals(25, AbsoluteValue, 'Absolute value of -25 should be 25');
    end;

    [Test]
    procedure TestStringContainsSubstring()
    var
        MainString: Text[100];
        SubString: Text[50];
        ContainsSubstring: Boolean;
    begin
        // [GIVEN] A clean test environment and strings
        Initialize();
        MainString := 'Business Central Development';
        SubString := 'Central';

        // [WHEN] Checking if main string contains substring
        ContainsSubstring := StrPos(MainString, SubString) > 0;

        // [THEN] The result should be true
        TestLibrary.AssertTrue(ContainsSubstring, 'Main string should contain the substring "Central"');
    end;

    [Test]
    procedure TestPowerOperationFails()
    var
        Base: Integer;
        Exponent: Integer;
        Result: Decimal;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        Base := 2;
        Exponent := 3;

        // [WHEN] Calculating power (simulated as multiplication)
        Result := Base * Base * Base;

        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertEquals(10, Result, 'Power 2^3 should equal 10 (intentional failure)');
    end;

    [Test]
    procedure TestZeroComparisonFails()
    var
        ZeroValue: Integer;
        IsZero: Boolean;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        ZeroValue := 0;

        // [WHEN] Checking if value is zero
        IsZero := ZeroValue = 0;

        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertTrue(not IsZero, 'Zero should not equal zero (intentional failure)');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
    end;
}
