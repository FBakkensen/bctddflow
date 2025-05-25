codeunit 50002 "Test Codeunit 50002"
{
    Subtype = Test;

    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";

    [Test]
    procedure TestMultiplicationReturnsCorrectProduct()
    var
        Result: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Multiplying two numbers
        Result := 4 * 6;

        // [THEN] The result should be correct
        TestLibrary.AssertEquals(24, Result, 'Multiplication of 4 * 6 should equal 24');
    end;

    [Test]
    procedure TestStringLengthIsCorrect()
    var
        TestString: Text[50];
        Length: Integer;
    begin
        // [GIVEN] A clean test environment and a test string
        Initialize();
        TestString := 'Hello World';

        // [WHEN] Getting the string length
        Length := StrLen(TestString);

        // [THEN] The length should be correct
        TestLibrary.AssertEquals(11, Length, 'Length of "Hello World" should be 11');
    end;

    [Test]
    procedure TestSubtractionReturnsWrongResult()
    var
        Result: Integer;
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Subtracting two numbers
        Result := 10 - 3;

        // [THEN] The result should be incorrect (intentional failure)
        TestLibrary.AssertEquals(8, Result, 'Subtraction 10 - 3 should equal 8 (intentional failure)');
    end;

    [Test]
    procedure TestBooleanLogicIsFalse()
    var
        Condition: Boolean;
    begin
        // [GIVEN] A clean test environment
        Initialize();
        Condition := true;

        // [WHEN] Testing the condition
        // [THEN] This should fail (intentional failure)
        TestLibrary.AssertTrue(not Condition, 'True should be False (intentional failure)');
    end;

    local procedure Initialize()
    begin
        // Initialize test setup
        TestSetup.Initialize();
    end;
}
