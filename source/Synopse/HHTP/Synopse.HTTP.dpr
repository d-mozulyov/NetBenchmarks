program Synopse.HTTP;

// Windows http.sys mORMot 1.18 server

// note: need to connect to http://127.0.0.1:1234/test

// todo: include mORMot 2 THttpAsyncServer for Linux - see https://github.com/d-mozulyov/NetBenchmarks/issues/1

{$APPTYPE CONSOLE}

uses
  WinApi.Windows,
  System.SysUtils,
  uServers,
  SynCrtSock,  // for THttpApiServer
  SynCommons;  // for TDocVariantData JSON process

type
  THttpServer = class(THttpApiServer)
  protected
    function DoGetBlank(Ctxt: THttpServerRequest): Cardinal;
    function DoGetWork(Ctxt: THttpServerRequest): Cardinal;
  end;

// mORMot has its own UTF-8 JSON engine: let's use it for the process
 
function ProcessJsonMormot(const input: RawUtf8): RawUtf8;
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

function THttpServer.DoGetBlank(Ctxt: THttpServerRequest): Cardinal;
begin
  Ctxt.OutContentType := TEXT_CONTENT;
  Ctxt.OutContent := BLANK_RESPONSE;
  Result := 200;
end;

function THttpServer.DoGetWork(Ctxt: THttpServerRequest): Cardinal;
begin
  Ctxt.OutContentType := JSON_CONTENT;
  Ctxt.OutContent := ProcessJsonMormot(Ctxt.InContent);
  Result := 200;
end;


var
  Server: THttpServer;
  status: integer;
begin
  Server := THttpServer.Create(false);
  try
    status := Server.AddUrl('test', UInt32ToUtf8(SERVER_PORT), false, '*', {register=}true);
    if status <> NO_ERROR then
      if status = ERROR_ACCESS_DENIED then
        writeln('Warning:'#13#10' Please run ONCE this project with Administrator ' +
          'rights, to register the'#13#10' http://127.0.0.1:', SERVER_PORT,
          '/test URI for the http.sys server'#13#10)
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
