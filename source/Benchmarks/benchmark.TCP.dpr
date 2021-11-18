program benchmark.TCP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks;

type
  TTCPClient = class(TIOCPClient)
  protected
    FSocket: TIOCPSocket;

    procedure DoInit; override;
    procedure DoRun; override;
    function DoCheck(const ABuffer: TIOCPBuffer): Boolean; override;
  public
    constructor Create(const AIndex: Integer); override;
    destructor Destroy; override;
  end;


{ TTCPClient }

constructor TTCPClient.Create(const AIndex: Integer);
begin
  inherited;
  FSocket := TIOCPSocket.Create(ipTCP);
end;

destructor TTCPClient.Destroy;
begin
  FSocket.Free;
  inherited;
end;

procedure TTCPClient.DoInit;
begin
  FSocket.Connect(TIOCPEndpoint.Default);

  if TBenchmark.WorkMode then
  begin
    FOutBuffer.WriteBytes(TBenchmark.WORK_REQUEST_BYTES);
  end else
  begin
    FOutBuffer.WriteBytes(TBenchmark.BLANK_REQUEST_BYTES);
  end;
end;

procedure TTCPClient.DoRun;
begin
  FSocket.Send(FOutBuffer);
  FSocket.Read(FInBuffer);
end;

function TTCPClient.DoCheck(const ABuffer: TIOCPBuffer): Boolean;
begin
  Result := True;
end;


begin
  TBenchmark.Run(TTCPClient);
end.
