codeunit 50099 "Test Library"
{
    // This codeunit provides additional test utilities
    // It is designed to be called from test codeunits to perform
    // common operations and assertions
    // It uses standard Microsoft test libraries directly

    var
        LibraryAssert: Codeunit "Library Assert";
        LibraryRandom: Codeunit "Library - Random";
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";

    // Assert that a condition is true
    procedure AssertTrue(Condition: Boolean; ErrorMessage: Text)
    begin
        LibraryAssert.IsTrue(Condition, ErrorMessage);
    end;

    // Assert that two values are equal
    procedure AssertEquals(Expected: Variant; Actual: Variant; ErrorMessage: Text)
    begin
        LibraryAssert.AreEqual(Expected, Actual, ErrorMessage);
    end;

    // Assert that two values are not equal
    procedure AssertNotEquals(Expected: Variant; Actual: Variant; ErrorMessage: Text)
    begin
        LibraryAssert.AreNotEqual(Expected, Actual, ErrorMessage);
    end;

    // Assert that two decimal values are approximately equal
    procedure AssertApproxEquals(Expected: Decimal; Actual: Decimal; Delta: Decimal; ErrorMessage: Text)
    begin
        LibraryAssert.AreNearlyEqual(Expected, Actual, Delta, ErrorMessage);
    end;

    // Fail a test with a specific error message
    procedure Fail(ErrorMessage: Text)
    begin
        LibraryAssert.Fail(ErrorMessage);
    end;

    // Generate a random integer within a range
    procedure GetRandomInteger(MinValue: Integer; MaxValue: Integer): Integer
    begin
        exit(LibraryRandom.RandIntInRange(MinValue, MaxValue));
    end;

    // Generate a random decimal within a range
    procedure GetRandomDecimal(MinValue: Decimal; MaxValue: Decimal; DecimalPlaces: Integer): Decimal
    begin
        exit(LibraryRandom.RandDecInRange(MinValue, MaxValue, DecimalPlaces));
    end;

    // Generate a random string of a specific length
    procedure GetRandomText(Length: Integer): Text
    begin
        exit(LibraryRandom.RandText(Length));
    end;

    // Generate a random date within a range
    procedure GetRandomDate(MinDate: Date; MaxDate: Date): Date
    begin
        exit(LibraryRandom.RandDateFromInRange(MinDate, MaxDate, 1));
    end;

    // Create a sales document
    procedure CreateSalesDocument(var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; CustomerNo: Code[20])
    begin
        LibrarySales.CreateSalesHeader(SalesHeader, DocumentType, CustomerNo);
    end;

    // Add a line to a sales document
    procedure AddSalesLine(var SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; ItemNo: Code[20]; Quantity: Decimal; UnitPrice: Decimal)
    begin
        LibrarySales.CreateSalesLine(SalesLine, SalesHeader, SalesLine.Type::Item, ItemNo, Quantity);
        SalesLine.Validate("Unit Price", UnitPrice);
        SalesLine.Modify(true);
    end;

    // Post a sales document
    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; Ship: Boolean; Invoice: Boolean): Code[20]
    begin
        exit(LibrarySales.PostSalesDocument(SalesHeader, Ship, Invoice));
    end;
}
