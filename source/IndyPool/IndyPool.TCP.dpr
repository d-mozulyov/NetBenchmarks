program IndyPool.TCP;

{$APPTYPE CONSOLE}

uses
  uServers,
  System.SysUtils,
  System.Classes,
  IdGlobal,
  IdContext,
  IdTCPServer,
  IdSchedulerOfThreadPool;

type
  TTcpServer = class(TIdTCPServer)
  protected
    procedure DoGetBlank(AContext: TIdContext);
    procedure DoGetWork(AContext: TIdContext);
  public
    constructor Create;
  end;


constructor TTcpServer.Create;
var
  LScheduler: TIdSchedulerOfThreadPool;
begin
  inherited Create(nil);

  LScheduler := TIdSchedulerOfThreadPool.Create(Self);
  LScheduler.PoolSize := 50;
  Self.Scheduler := LScheduler;
end;

procedure TTcpServer.DoGetBlank(AContext: TIdContext);
var
  LSize: Cardinal;
  LBuffer: TBytes;
begin
  LSize := AContext.Connection.Socket.ReadUInt32(False);
  if (LSize <> 0) then
  begin
    SetLength(LBuffer, LSize);
    AContext.Connection.Socket.ReadBytes(TIdBytes(LBuffer), LSize, False);
  end;

  LSize := Length(BLANK_RESPONSE_BYTES);
  AContext.Connection.Socket.Write(LSize, False);
  AContext.Connection.Socket.WriteDirect(TIdBytes(BLANK_RESPONSE_BYTES), LSize);
end;

procedure TTcpServer.DoGetWork(AContext: TIdContext);
var
  LSize: Cardinal;
  LSource, LTarget: TBytes;
begin
  LSize := AContext.Connection.Socket.ReadUInt32(False);
  SetLength(LSource, LSize);
  AContext.Connection.Socket.ReadBytes(TIdBytes(LSource), LSize, False);
  LTarget := ProcessJson(LSource);

  LSize := Length(LTarget);
  AContext.Connection.Socket.Write(LSize, False);
  AContext.Connection.Socket.WriteDirect(TIdBytes(LTarget), LSize);
end;


var
  Server: TTcpServer;

begin
  Server := TTcpServer.Create;
  try
    LogServerListening(Server);

    if (not WORK_MODE) then
    begin
      Server.OnExecute := Server.DoGetBlank;
    end else
    begin
      Server.OnExecute := Server.DoGetWork;
    end;

    Server.Bindings.Add.Port := SERVER_PORT;
    Server.Active := True;

    SleepLoop;

  finally
    Server.Free;
  end;

end.
