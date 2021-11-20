program benchmark.WebSocket;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks,
  System.SysUtils;
  

type
  TWebSocketClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TWebSocketClient);
end.
