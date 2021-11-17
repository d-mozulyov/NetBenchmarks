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

    class procedure BenchmarkInit; override;
    procedure DoInit; override;
    procedure DoRun; override;
    function InternalCheck(const ABuffer: TIOCPBuffer): Boolean;
    function InBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean; override;
  public
    constructor Create(const AIndex: Integer); override;
    destructor Destroy; override;
  end;


{ TTCPClient }

class procedure TTCPClient.BenchmarkInit;
begin
  inherited;
  // ToDo
end;

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
end;

procedure TTCPClient.DoRun;
begin

end;

function TTCPClient.InternalCheck(const ABuffer: TIOCPBuffer): Boolean;
begin
  Result := True;
end;

function TTCPClient.InBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
begin
  Result := inherited InBufferCallback(AParam, AErrorCode, ASize);
  if (not Result) then
    Exit;

  Result := (not TBenchmark.CheckMode) or InternalCheck(InBuffer);
  Done(TBenchmark.CHECK_ERRORS[Result]);
end;

begin
  TBenchmark.Run(TTCPClient);
end.
