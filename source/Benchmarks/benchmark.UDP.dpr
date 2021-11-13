program benchmark.UDP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks;

type
  TUDPClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TUDPClient);
end.
