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
  public

    property Connection: ICrossConnection read FConnection;
  end;


{ TTCPClient }

class procedure TTCPClient.BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean);
begin
end;



begin
  TBenchmark.Run(TTCPClient);
end.
