program benckmark.TCP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks,
  System.SysUtils;

type
  TTCPClient = class(TBenchmarkClient)
  protected

  public

  end;


begin
  TBenchmark.Run(TTCPClient, [
    ''
  ]);
end.
