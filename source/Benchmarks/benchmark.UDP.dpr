program benchmark.UDP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks;

type
  TUDPClient = class(TClient)
  protected
    class var
      GCTimestamp: Cardinal;

    class procedure BenchmarkInit; override;
    //class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
    //procedure DoRun; override;
    //procedure DoInit; override;
  public

  end;


{ TUDPClient }

class procedure TUDPClient.BenchmarkInit;
begin
  GCTimestamp := TBenchmark.Timestamp;
end;

class procedure TUDPClient.BenchmarkProcess;
var
  LTimestamp: Cardinal;
begin
  LTimestamp := TBenchmark.Timestamp;
  if (Cardinal(LTimestamp - GCTimestamp) < 5) then
  begin
    Exit;
  end;
  GCTimestamp := LTimestamp;

end;


begin
  TBenchmark.Run(TUDPClient);
end.
