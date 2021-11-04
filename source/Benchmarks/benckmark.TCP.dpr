program benckmark.TCP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks,
  System.SysUtils,
  Net.CrossSocket.Base,
  Net.CrossSocket;

type
  TTCPClient = class(TBenchmarkClient)
  protected
    FConnection: ICrossConnection;

    class procedure BenchmarkInitBlank; override;
    class procedure BenchmarkInitWork; override;
  public
    procedure Init; override;
    procedure Stop; override;

    property Connection: ICrossConnection read FConnection;
  end;


{ TTCPClient }

class procedure TTCPClient.BenchmarkInitBlank;
begin
end;

class procedure TTCPClient.BenchmarkInitWork;
begin
end;

procedure TTCPClient.Init;
begin
 // FConnection := TCrossConnection.Create(nil, );
end;

procedure TTCPClient.Stop;
begin
  FConnection := nil;
end;

begin
  TBenchmark.Run(TTCPClient, [
    ''
  ]);
end.
