codeunit 50000 "HelloWorld Test"
{
    Subtype = Test;

    // Local variables
    var
        TestLibrary: Codeunit "Test Library";
        TestSetup: Codeunit "Test Setup";
        MessageDisplayed: Boolean;

    // Test initialization
    [Test]
    procedure TestInitialize()
    begin
        // Initialize test environment
        TestSetup.Initialize();
    end;

    // Test that the hello world message is displayed
    [Test]
    [HandlerFunctions('HelloWorldMessageHandler')]
    [TestPermissions(TestPermissions::Disabled)]
    procedure TestHelloWorldMessage()
    var
        CustList: TestPage "Customer List";
    begin
        // [GIVEN] A clean test environment
        Initialize();

        // [WHEN] Opening the Customer List page
        CustList.OpenView();
        CustList.Close();

        // [THEN] The hello world message should be displayed
        TestLibrary.AssertTrue(MessageDisplayed, 'Message was not displayed!');
    end;

    // Message handler for the hello world message
    [MessageHandler]
    procedure HelloWorldMessageHandler(Message: Text[1024])
    begin
        MessageDisplayed := MessageDisplayed or (Message = 'App published: Hello world');
    end;

    // Initialize test
    local procedure Initialize()
    begin
        // Reset message displayed flag
        MessageDisplayed := false;

        // Initialize test setup
        TestSetup.Initialize();
    end;
}

