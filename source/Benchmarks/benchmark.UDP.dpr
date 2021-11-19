program benchmark.UDP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks,
  System.SysUtils;


type
  TUDPClient = class(TIOCPClient)
  protected
    const
      GCTIMEOUT = 5;
    class var
      InSocket: TIOCPSocket;
      GCTimestamp: Cardinal;

    class procedure BenchmarkInit; override;
    class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
  protected
    FPacketId: Integer;
    FTimestamp: Cardinal;

    procedure DoInit; override;
    procedure DoRun; override;
  public

  end;


{ TUDPClient }

class procedure TUDPClient.BenchmarkInit;
begin
  inherited;
  TUDPClient.InSocket := TIOCPSocket.Create(TIOCPClient.PrimaryIOCP, ipUDP);
  TUDPClient.GCTimestamp := TBenchmark.Timestamp;
end;

class procedure TUDPClient.BenchmarkFinal;
begin
  FreeAndNil(TUDPClient.InSocket);
  inherited;
end;

class procedure TUDPClient.BenchmarkProcess;
var
  LTimestamp: Cardinal;
begin
  inherited;

  LTimestamp := TBenchmark.Timestamp;
  if (Cardinal(LTimestamp - GCTimestamp) < GCTIMEOUT) then
  begin
    Exit;
  end;
  GCTimestamp := LTimestamp;


end;

procedure TUDPClient.DoInit;
var
  LOutSocket: TIOCPSocket;
begin
  inherited;

  LOutSocket := TIOCPSocket.Create(TIOCPClient.PrimaryIOCP, ipUDP);
  InitObjects(TUDPClient.InSocket, False, LOutSocket, False);
  LOutSocket.Connect;

  // out buffer initialization
  FOutBuffer.Alloc(SizeOf(Integer));
  if TBenchmark.WorkMode then
  begin
    FOutBuffer.WriteBytes(TBenchmark.WORK_REQUEST_BYTES);
  end else
  begin
    FOutBuffer.WriteBytes(TBenchmark.BLANK_REQUEST_BYTES);
  end;
end;

procedure TUDPClient.DoRun;
begin
  Inc(FPacketId);
  FTimestamp := TBenchmark.Timestamp;
  PInteger(FOutBuffer.Bytes)^ := FPacketId;

  inherited;
end;

begin
  TBenchmark.Run(TUDPClient);
end.
