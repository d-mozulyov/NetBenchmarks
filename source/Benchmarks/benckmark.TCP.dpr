program benckmark.TCP;

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
  TBenchmark.Run(TTCPClient, [
    'bin/HTTP/Indy.HTTP',
    'bin/HTTP/IndyPool.HTTP',
    'bin/HTTP/RealThinClient.HTTP',
    'bin/HTTP/Synopse.HTTP',
    'bin/HTTP/TMSSparkle.HTTP',
    'node source/Node.js/Node.HTTP.js',
    'bin/HTTP/Golang.HTTP'
  ]);
end.
