unit uSynopseJSON;

// mORMot has its own UTF-8 JSON engine: let's use it for the process

interface
uses
  System.SysUtils,
  SynCommons;


// first method using a TDocVariantData document
function ProcessJsonMormotDocVariant(const input: RawUtf8): RawUtf8;
// second method using RTTI over records (as golang does)
function ProcessJsonMormotRtti(const input: RawUtf8): RawUtf8;

implementation

function ProcessJsonMormotDocVariant(const input: RawUtf8): RawUtf8;
var
  json: TDocVariantData;
  group, dates: PDocVariantData;
  minDate, maxDate, dt: TDateTime;
  n: PtrInt;
begin
  json.InitJsonInPlace(pointer(input), JSON_OPTIONS_FAST);
  group := json.O['group'];
  dates := group.A['dates'];
  minDate := MaxDateTime;
  maxDate := MinDateTime;
  for n := 0 to dates.Count - 1 do
  begin
    dt := Iso8601ToDateTime(VariantToUtf8(dates.Values[n]));
    if dt < minDate then
      minDate := dt;
    if dt > maxDate then
      maxDate := dt;
  end;
  result := JsonEncode([
    'product',   json.U['product'],
    'requestId', json.U['requestId'],
    'client', '{',
                   'balance', group.U['balance'],
                   'minDate', DateTimeToIso8601Text(minDate, 'T', true) + 'Z',
                   'maxDate', DateTimeToIso8601Text(maxDate, 'T', true) + 'Z',
              '}']);
end;

// second method using RTTI over records (as golang does)

type
  TRequest = packed record
    product: RawUtf8;
    requestId: RawUtf8;
    group: packed record
      kind: RawUtf8;
      default: boolean;
      balance: currency;
      dates: TDateTimeMSDynArray;
    end;
  end;

  TResponse = packed record
    product: RawUtf8;
    requestId: RawUtf8;
    client: packed record
      balance: currency;
      minDate, maxDate: TDateTimeMS;
    end;
  end;

function ProcessJsonMormotRtti(const input: RawUtf8): RawUtf8;
var
  req: TRequest;
  resp: TResponse;
  dt: TDateTime;
  n: PtrInt;
begin
  RecordLoadJson(req, pointer(input), TypeInfo(TRequest));
  resp.product := req.product;
  resp.requestId := req.requestId;
  resp.client.minDate := MaxDateTime;
  resp.client.maxDate := MinDateTime;
  resp.client.balance := req.group.balance;
  for n := 0 to high(req.group.dates) do
  begin
    dt := req.group.dates[n];
    if dt < resp.client.minDate then
      resp.client.minDate := dt;
    if dt > resp.client.maxDate then
      resp.client.maxDate := dt;
  end;
  SaveJson(resp, TypeInfo(TResponse), [twoDateTimeWithZ], result);
end;

end.
