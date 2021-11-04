program Synopse.HTTP;

// Windows http.sys mORMot 1.18 server

// todo: include mORMot 2 THttpAsyncServer for Linux - see https://github.com/d-mozulyov/NetBenchmarks/issues/1

{$APPTYPE CONSOLE}

uses
  WinApi.Windows,
  System.SysUtils,
  uServers,
  SynCrtSock,  // for THttpApiServer
  SynCommons;  // for JSON process

type
  THttpServer = class(THttpApiServer)
  protected
    function DoGetBlank(Ctxt: THttpServerRequest): Cardinal;
    function DoGetWork(Ctxt: THttpServerRequest): Cardinal;
  end;

// mORMot has its own UTF-8 JSON engine: let's use it for the process
 
// first method using a TDocVariantData document

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


function THttpServer.DoGetBlank(Ctxt: THttpServerRequest): Cardinal;
begin
  Ctxt.OutContentType := TEXT_CONTENT;
  Ctxt.OutContent := BLANK_RESPONSE;
  Result := 200;
end;

function THttpServer.DoGetWork(Ctxt: THttpServerRequest): Cardinal;
begin
  Ctxt.OutContentType := JSON_CONTENT;
  //Ctxt.OutContent := ProcessJsonMormotDocVariant(Ctxt.InContent);
  Ctxt.OutContent := ProcessJsonMormotRtti(Ctxt.InContent);
  Result := 200;
end;


var
  Server: THttpServer;
  status: integer;
begin
  Server := THttpServer.Create(false);
  try
    status := Server.AddUrl('', UInt32ToUtf8(SERVER_PORT), false, '*', {register=}true);
    if status <> NO_ERROR then
      if status = ERROR_ACCESS_DENIED then
        writeln('Warning:'#13#10' Please run ONCE this project with Administrator ' +
          'rights, to register the'#13#10' http://127.0.0.1:', SERVER_PORT,
          ' URI for the http.sys server'#13#10)
      else
        raise Exception.CreateFmt('AddUrl returned %d', [status]);

    LogServerListening(Server);

    if (not WORK_MODE) then
    begin
      Server.OnRequest := Server.DoGetBlank;
    end else
    begin
      Server.OnRequest := Server.DoGetWork;
    end;

    SleepLoop;
    Server.Shutdown;

  finally
    Server.Free;
  end;

end.
