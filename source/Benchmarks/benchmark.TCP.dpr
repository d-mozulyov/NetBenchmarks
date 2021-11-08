program benchmark.TCP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks,
  System.SysUtils,
  Net.CrossSocket.Base,
  Net.CrossSocket;

type
  TTCPClient = class(TClient)
  protected
    FConnection: ICrossConnection;

    class procedure BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean); override;
    procedure DoRun; override;
    procedure DoInit; override;
  public
    constructor Create(const AIndex: Integer; const AWorkMode, ACheckMode: Boolean); override;
    destructor Destroy; override;

    property Connection: ICrossConnection read FConnection;
  end;


{ TTCPClient }

class procedure TTCPClient.BenchmarkInit(const AClientCount: Integer;
  const AWorkMode: Boolean);
begin
  inherited;

end;

constructor TTCPClient.Create(const AIndex: Integer; const AWorkMode,
  ACheckMode: Boolean);
begin
  inherited;

end;

destructor TTCPClient.Destroy;
begin

  inherited;
end;

procedure TTCPClient.DoInit;
begin

end;

procedure TTCPClient.DoRun;
begin

end;


begin
  TBenchmark.Run(TTCPClient);
end.
