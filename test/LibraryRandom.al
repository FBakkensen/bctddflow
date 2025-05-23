codeunit 50090 "Library - Random"
{
    // This codeunit provides random data generation functionality
    // It is designed to be used by test codeunits to generate random test data

    // Generate a random integer within a range
    procedure RandIntInRange(MinValue: Integer; MaxValue: Integer): Integer
    begin
        if MinValue = MaxValue then
            exit(MinValue);

        exit(MinValue + Random(MaxValue - MinValue + 1));
    end;

    // Generate a random decimal within a range
    procedure RandDecInRange(MinValue: Decimal; MaxValue: Decimal; DecimalPlaces: Integer): Decimal
    var
        RandomValue: Decimal;
        Multiplier: Decimal;
    begin
        if MinValue = MaxValue then
            exit(MinValue);

        Multiplier := Power(10, DecimalPlaces);
        RandomValue := MinValue + (Random(Round((MaxValue - MinValue) * Multiplier)) / Multiplier);
        exit(Round(RandomValue, 0.00001));
    end;

    // Generate a random string of a specific length
    procedure RandText(Length: Integer): Text
    var
        Result: Text;
        Chars: Text;
        i: Integer;
    begin
        Chars := 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
        Result := '';

        for i := 1 to Length do
            Result += CopyStr(Chars, RandIntInRange(1, StrLen(Chars)), 1);

        exit(Result);
    end;

    // Generate a random date within a range
    procedure RandDateFromInRange(MinDate: Date; MaxDate: Date; Step: Integer): Date
    var
        DaysDiff: Integer;
    begin
        if MinDate = MaxDate then
            exit(MinDate);

        DaysDiff := MaxDate - MinDate;
        exit(MinDate + RandIntInRange(0, DaysDiff));
    end;
}
