program benchmark.HTTP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks;

type
  THttpClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(THttpClient);
end.
