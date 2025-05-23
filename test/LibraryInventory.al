codeunit 50092 "Library - Inventory"
{
    // This codeunit provides inventory functionality for tests
    // It is designed to be used by test codeunits to create and manipulate inventory items

    var
        LibraryRandom: Codeunit "Library - Random";

    // Create an item
    procedure CreateItem(var Item: Record Item)
    begin
        Item.Init();
        Item."No." := Format(Today) + Format(Time) + Format(Random(1000));
        Item.Description := 'Test Item ' + Item."No.";
        Item.Insert(true);
    end;

    // Create an item with a specific unit price
    procedure CreateItemWithUnitPrice(var Item: Record Item; UnitPrice: Decimal)
    begin
        CreateItem(Item);
        Item."Unit Price" := UnitPrice;
        Item.Modify(true);
    end;

    // Create an item with inventory
    procedure CreateItemWithInventory(var Item: Record Item; LocationCode: Code[10]; Quantity: Decimal; UnitCost: Decimal)
    begin
        CreateItem(Item);

        // In a real implementation, this would post an item journal to update inventory
        // For now, we'll just set the inventory field directly
        Item.Inventory := Quantity;
        Item."Unit Cost" := UnitCost;
        Item.Modify(true);
    end;
}
