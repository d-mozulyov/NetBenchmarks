program Synopse.HTTP;

{$APPTYPE CONSOLE}

uses
  uServers,
  System.SysUtils,
  SynCrtSock,
  SynBidirSock;

type
  THttpServer = class(SynCrtSock.THttpServer)
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
  Ctxt.OutContent := SockString(ProcessJson(string(Ctxt.InContent)));
  Result := 200;
end;


var
  Server: THttpServer;

begin
  Server := THttpServer.Create(SockString(IntToStr(SERVER_PORT)), nil, nil, 'xSynopseServer');
  try
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
