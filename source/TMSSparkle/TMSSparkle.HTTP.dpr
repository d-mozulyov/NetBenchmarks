program TMSSparkle.HTTP;

{$APPTYPE CONSOLE}

uses
  uServers,
  System.SysUtils,
  Sparkle.HttpSys.Server,
  Sparkle.HttpServer.Dispatcher,
  Sparkle.HttpServer.Module,
  Sparkle.HttpServer.Context;

type
  THttpServer = class(THttpSysServer)
  protected
    type
      TBlankModule = class(THttpServerModule)
        public procedure ProcessRequest(const C: THttpServerContext); override;
      end;
      TWorkModule = class(THttpServerModule)
        public procedure ProcessRequest(const C: THttpServerContext); override;
      end;
  end;


procedure THttpServer.TBlankModule.ProcessRequest(const C: THttpServerContext);
begin
  C.Response.StatusCode := 200;
  C.Response.ContentType := TEXT_CONTENT;
  C.Response.Close(TEncoding.UTF8.GetBytes(BLANK_RESPONSE));
end;

procedure THttpServer.TWorkModule.ProcessRequest(const C: THttpServerContext);
begin
  C.Response.StatusCode := 200;
  C.Response.ContentType := JSON_CONTENT;
  C.Response.Close(ProcessJson(C.Request.Content));
end;


var
  Server: THttpServer;
  Uri: string;

begin
  Server := THttpServer.Create;
  try
    LogServerListening(Server);

    Server.KeepHostInUrlPrefixes:=True;
    Uri := 'http://127.0.0.1:' + IntToStr(SERVER_PORT) + '/';
    if (not WORK_MODE) then
    begin
      Server.Dispatcher.AddModule(THttpServer.TBlankModule.Create(Uri));
    end else
    begin
      Server.Dispatcher.AddModule(THttpServer.TWorkModule.Create(Uri));
    end;

    Server.Start;
    SleepLoop;
    Server.Stop;

  finally
    Server.Free;
  end;

end.
