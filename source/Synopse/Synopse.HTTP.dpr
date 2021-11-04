program Synopse.HTTP;

// Windows http.sys mORMot 1.18 server

// todo: include mORMot 2 THttpAsyncServer for Linux - see https://github.com/d-mozulyov/NetBenchmarks/issues/1

{$APPTYPE CONSOLE}

uses
  uServers,
  uSynopseJSON, // mORMot has its own UTF-8 JSON engine: let's use it for the process
  WinApi.Windows,
  System.SysUtils,
  SynCrtSock, // for THttpApiServer
  SynCommons;


type
  THttpServer = class(THttpApiServer)
  protected
    function DoGetBlank(Ctxt: THttpServerRequest): Cardinal;
    function DoGetWork(Ctxt: THttpServerRequest): Cardinal;
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
