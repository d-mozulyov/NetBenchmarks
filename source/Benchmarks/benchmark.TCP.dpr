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
    function DoCheck(const ABuffer: TIOCPBuffer): Boolean; override;
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

function TTCPClient.DoCheck(const ABuffer: TIOCPBuffer): Boolean;
begin
  Result := True;
end;


begin
  TBenchmark.Run(TTCPClient);
end.
