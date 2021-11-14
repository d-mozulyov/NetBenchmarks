program benchmark.Pipe;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks;

type
  TPipeClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TPipeClient);
end.
