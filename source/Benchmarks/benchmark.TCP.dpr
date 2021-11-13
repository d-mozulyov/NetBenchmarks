program benchmark.TCP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks;

type
  TTCPClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TTCPClient);
end.
