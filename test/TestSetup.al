codeunit 50097 "Test Setup"
{
    // This codeunit handles common test setup and teardown operations
    // It is designed to be called from test codeunits to initialize
    // and clean up the test environment

    var
        LibrarySales: Codeunit "Library - Sales";
        LibraryInventory: Codeunit "Library - Inventory";
        IsInitialized: Boolean;

    // Initialize the test environment
    procedure Initialize()
    begin
        if IsInitialized then
            exit;

        // Perform initialization for all tests
        SetupTestData();

        IsInitialized := true;
    end;

    // Set up test data
    local procedure SetupTestData()
    begin
        // Set up any common test data here
        // For example, create test customers, items, etc.
    end;

    // Clean up the test environment
    procedure Teardown()
    begin
        if not IsInitialized then
            exit;

        // Clean up any test data
        CleanupTestData();

        IsInitialized := false;
    end;

    // Clean up test data
    local procedure CleanupTestData()
    begin
        // Clean up any test data created during setup
        // For example, delete test customers, items, etc.
    end;

    // Create a test customer
    procedure CreateTestCustomer(): Code[20]
    var
        Customer: Record Customer;
    begin
        LibrarySales.CreateCustomer(Customer);
        exit(Customer."No.");
    end;

    // Create a test item
    procedure CreateTestItem(): Code[20]
    var
        Item: Record Item;
    begin
        LibraryInventory.CreateItem(Item);
        exit(Item."No.");
    end;
}
