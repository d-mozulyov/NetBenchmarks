program benchmark.WebSocket;

{$APPTYPE CONSOLE}

uses
  uBenchmarks;

type
  TWebSocketClient = class(TClient)
  protected

  public

  end;

begin
  TBenchmark.Run(TWebSocketClient);
end.
