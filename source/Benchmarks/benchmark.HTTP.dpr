program benchmark.HTTP;

{$APPTYPE CONSOLE}

uses
  uBenchmarks;

type
  THttpClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(THttpClient);
end.
