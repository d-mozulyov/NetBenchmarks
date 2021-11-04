program IndyPool.HTTP;

{$APPTYPE CONSOLE}

uses
  uServers,
  System.SysUtils,
  IdContext,
  IdCustomHTTPServer,
  IdHTTPServer,
  IdSchedulerOfThreadPool;


type
  THttpServer = class(TIdHTTPServer)
  protected
    procedure DoGetBlank(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure DoGetWork(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
  public
    constructor Create;
  end;


constructor THttpServer.Create;
var
  LScheduler: TIdSchedulerOfThreadPool;
begin
  inherited Create(nil);

  LScheduler := TIdSchedulerOfThreadPool.Create(Self);
  LScheduler.PoolSize := 50;
  Self.Scheduler := LScheduler;
end;

procedure THttpServer.DoGetBlank(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
begin
  AResponseInfo.ContentType := TEXT_CONTENT;
  AResponseInfo.ContentText := BLANK_RESPONSE;
end;

procedure THttpServer.DoGetWork(AContext: TIdContext; ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
begin
  if (Assigned(ARequestInfo.PostStream)) then
  begin
    AResponseInfo.ContentType := JSON_CONTENT;
    AResponseInfo.ContentText := ProcessJson(ARequestInfo.PostStream);
  end else
  begin
    DoGetBlank(AContext, ARequestInfo, AResponseInfo);
  end;
end;


var
  Server: THttpServer;

begin
  Server := THttpServer.Create;
  try
    LogServerListening(Server);

    if (not WORK_MODE) then
    begin
      Server.OnCommandGet := Server.DoGetBlank;
    end else
    begin
      Server.OnCommandGet := Server.DoGetWork;
    end;

    Server.Bindings.Add.Port := SERVER_PORT;
    Server.Active := True;

    SleepLoop;

  finally
    Server.Free;
  end;

end.

