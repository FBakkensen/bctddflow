codeunit 50091 "Library - Sales"
{
    // This codeunit provides sales functionality for tests
    // It is designed to be used by test codeunits to create and manipulate sales documents

    var
        LibraryRandom: Codeunit "Library - Random";

    // Create a customer
    procedure CreateCustomer(var Customer: Record Customer)
    begin
        Customer.Init();
        Customer."No." := Format(Today) + Format(Time) + Format(Random(1000));
        Customer.Name := 'Test Customer ' + Customer."No.";
        Customer.Insert(true);
    end;

    // Create a sales header
    procedure CreateSalesHeader(var SalesHeader: Record "Sales Header"; DocumentType: Enum "Sales Document Type"; CustomerNo: Code[20])
    begin
        SalesHeader.Init();
        SalesHeader."Document Type" := DocumentType;
        SalesHeader."Sell-to Customer No." := CustomerNo;
        SalesHeader.Insert(true);
    end;

    // Create a sales line
    procedure CreateSalesLine(var SalesLine: Record "Sales Line"; SalesHeader: Record "Sales Header"; LineType: Enum "Sales Line Type"; No: Code[20]; Quantity: Decimal)
    begin
        SalesLine.Init();
        SalesLine."Document Type" := SalesHeader."Document Type";
        SalesLine."Document No." := SalesHeader."No.";
        SalesLine."Line No." := GetNextSalesLineNo(SalesHeader);
        SalesLine.Type := LineType;
        SalesLine."No." := No;
        SalesLine.Quantity := Quantity;
        SalesLine.Insert(true);
    end;

    // Get the next line number for a sales line
    local procedure GetNextSalesLineNo(SalesHeader: Record "Sales Header"): Integer
    var
        SalesLine: Record "Sales Line";
        NextLineNo: Integer;
    begin
        SalesLine.SetRange("Document Type", SalesHeader."Document Type");
        SalesLine.SetRange("Document No.", SalesHeader."No.");

        if SalesLine.FindLast() then
            NextLineNo := SalesLine."Line No." + 10000
        else
            NextLineNo := 10000;

        exit(NextLineNo);
    end;

    // Post a sales document
    procedure PostSalesDocument(var SalesHeader: Record "Sales Header"; Ship: Boolean; Invoice: Boolean): Text
    var
        PostedDocNo: Text;
    begin
        SalesHeader.Ship := Ship;
        SalesHeader.Invoice := Invoice;

        // In a real implementation, this would call SalesPost.Run
        // For now, we'll just return a dummy document number
        PostedDocNo := 'TEST' + SalesHeader."No.";

        exit(PostedDocNo);
    end;
}
