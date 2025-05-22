codeunit 50099 "Test Library"
{
    // This codeunit provides additional test utilities
    // It is designed to be called from test codeunits to perform
    // common operations and assertions

    var
        TestSuite: Codeunit "Test Suite";

    // Assert that a condition is true
    procedure AssertTrue(Condition: Boolean; ErrorMessage: Text)
    begin
        TestSuite.AssertTrue(Condition, ErrorMessage);
    end;

    // Assert that two values are equal
    procedure AssertEquals(Expected: Variant; Actual: Variant; ErrorMessage: Text)
    begin
        TestSuite.AssertEquals(Expected, Actual, ErrorMessage);
    end;

    // Assert that two values are not equal
    procedure AssertNotEquals(Expected: Variant; Actual: Variant; ErrorMessage: Text)
    begin
        TestSuite.AssertNotEquals(Expected, Actual, ErrorMessage);
    end;

    // Assert that two decimal values are approximately equal
    procedure AssertApproxEquals(Expected: Decimal; Actual: Decimal; Delta: Decimal; ErrorMessage: Text)
    begin
        TestSuite.AssertApproxEquals(Expected, Actual, Delta, ErrorMessage);
    end;

    // Fail a test with a specific error message
    procedure Fail(ErrorMessage: Text)
    begin
        TestSuite.Fail(ErrorMessage);
    end;

    // Generate a random integer within a range
    procedure GetRandomInteger(MinValue: Integer; MaxValue: Integer): Integer
    begin
        exit(TestSuite.GetRandomInteger(MinValue, MaxValue));
    end;

    // Generate a random decimal within a range
    procedure GetRandomDecimal(MinValue: Decimal; MaxValue: Decimal; DecimalPlaces: Integer): Decimal
    begin
        exit(TestSuite.GetRandomDecimal(MinValue, MaxValue, DecimalPlaces));
    end;

    // Generate a random string of a specific length
    procedure GetRandomText(Length: Integer): Text
    begin
        exit(TestSuite.GetRandomText(Length));
    end;

    // Generate a random date within a range
    procedure GetRandomDate(MinDate: Date; MaxDate: Date): Date
    begin
        exit(TestSuite.GetRandomDate(MinDate, MaxDate));
    end;

    // Create a sales document
    procedure CreateSalesDocument(var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; CustomerNo: Code[20])
    begin
        TestSuite.CreateSalesDocument(SalesHeader, DocumentType, CustomerNo);
    end;

    // Add a line to a sales document
    procedure AddSalesLine(var SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; ItemNo: Code[20]; Quantity: Decimal; UnitPrice: Decimal)
    begin
        TestSuite.AddSalesLine(SalesLine, SalesHeader, ItemNo, Quantity, UnitPrice);
    end;

    // Post a sales document
    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; Ship: Boolean; Invoice: Boolean): Code[20]
    begin
        exit(TestSuite.PostSalesDocument(SalesHeader, Ship, Invoice));
    end;
}
