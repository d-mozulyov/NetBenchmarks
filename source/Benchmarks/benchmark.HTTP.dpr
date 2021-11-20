program benchmark.HTTP;

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
  THttpClient = class(TIOCPClient)
  protected
    class function BenchmarkDefaultOutMessage: TBytes; override;
    procedure DoInit; override;
    procedure DoRun; override;
  public

  end;


{ THttpClient }

class function THttpClient.BenchmarkDefaultOutMessage: TBytes;
var
  LBuffer: UTF8String;
begin
  if TBenchmark.WorkMode then
  begin
    LBuffer := TBenchmark.WORK_RESPONSE_UTF8;
  end else
  begin
    LBuffer := TBenchmark.BLANK_RESPONSE_UTF8;
  end;

  // ToDo

  SetLength(Result, Length(LBuffer));
  Move(Pointer(LBuffer)^, Pointer(Result)^, Length(LBuffer));
end;

procedure THttpClient.DoInit;
var
  LSocket: TIOCPSocket;
begin
  inherited;

  LSocket := TIOCPSocket.Create(TIOCPClient.PrimaryIOCP, ipTCP);
  InitObjects(LSocket, True);
end;

procedure THttpClient.DoRun;
begin
  inherited;

end;

begin
  TBenchmark.Run(THttpClient);
end.
