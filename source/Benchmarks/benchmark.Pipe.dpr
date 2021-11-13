program benchmark.Pipe;

{$APPTYPE CONSOLE}

uses
  uBenchmarks;

type
  TPipeClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TPipeClient);
end.
