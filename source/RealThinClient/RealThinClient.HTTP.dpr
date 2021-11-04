program RealThinClient.HTTP;

{$APPTYPE CONSOLE}

uses
  uServers,
  System.SysUtils,
  rtcTypes,
  rtcSystem,
  rtcInfo,
  rtcConn,
  rtcDataSrv,
  rtcHttpSrv;

type
  THttpServer = class(TRtcHttpServer)
  protected
    procedure DoCheckRequest(Sender: TRtcConnection);
    procedure DoGetBlank(Sender: TRtcConnection);
    procedure DoGetWork(Sender: TRtcConnection);
  end;

procedure THttpServer.DoCheckRequest(Sender: TRtcConnection);
begin
  Sender.Accept;
end;

procedure THttpServer.DoGetBlank(Sender: TRtcConnection);
begin
  if (Sender.Request.Complete) then
  begin
    Sender.Response.ContentType := TEXT_CONTENT;
    Sender.Write(BLANK_RESPONSE);
  end;
end;

procedure THttpServer.DoGetWork(Sender: TRtcConnection);
begin
  if (Sender.Request.Complete) then
  begin
    Sender.Response.ContentType := JSON_CONTENT;
    Sender.Write(ProcessJson(Sender.Read));
  end;
end;


var
  Server: THttpServer;

begin
  Server := THttpServer.Create(nil);
  try
    LogServerListening(Server);

    with TRtcDataProvider.Create(Server) do
    begin
      Server := RealThinClient.HTTP.Server;
      OnCheckRequest := RealThinClient.HTTP.Server.DoCheckRequest;
      if (not WORK_MODE) then
      begin
        OnDataReceived := RealThinClient.HTTP.Server.DoGetBlank;
      end else
      begin
        OnDataReceived := RealThinClient.HTTP.Server.DoGetWork;
      end;
    end;

    Server.ServerAddr := 'localhost';
    Server.ServerPort := IntToStr(SERVER_PORT);
    Server.ServerIPV := rtc_IPVDefault;
    Server.MultiThreaded := True;

    Server.Listen;

    SleepLoop;
    Server.StopListenNow;
  finally
    Server.Free;
  end;


end.
