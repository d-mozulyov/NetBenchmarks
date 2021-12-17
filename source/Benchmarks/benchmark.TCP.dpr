program benchmark.TCP;

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
  TTCPClient = class(TIOCPClient)
  protected
    class function BenchmarkDefaultOutMessage: TBytes; override;
    procedure DoInit; override;
    procedure DoRun; override;
    function DoGetMessageSize(const ABytes: TBytes; const ASize: Integer): Integer; override;
    function DoCheckMessage(const ABytes: TBytes; const ASize: Integer): Boolean; override;
  public

  end;


{ TTCPClient }

class function TTCPClient.BenchmarkDefaultOutMessage: TBytes;
begin
  SetLength(Result, SizeOf(Integer));

  if TBenchmark.WorkMode then
  begin
    Result := Result + TBenchmark.WORK_REQUEST_BYTES;
  end else
  begin
    Result := Result + TBenchmark.BLANK_REQUEST_BYTES;
  end;

  PInteger(Result)^ := Length(Result) - SizeOf(Integer);
end;

procedure TTCPClient.DoInit;
var
  LSocket: TIOCPSocket;
begin
  inherited;

  LSocket := TIOCPSocket.Create(TIOCPClient.PrimaryIOCP, ipTCP);
  InitObjects(LSocket, True);
  LSocket.Connect;
end;

procedure TTCPClient.DoRun;
begin
  OutObject.OverlappedWrite(FOutBuffer);
  InObject.OverlappedRead(FInBuffer);
end;

function TTCPClient.DoGetMessageSize(const ABytes: TBytes;
  const ASize: Integer): Integer;
begin
  if (ASize < SizeOf(Integer)) then
  begin
    Result := SizeOf(Integer);
  end else
  begin
    Result := SizeOf(Integer) + PInteger(ABytes)^;
  end;
end;

function TTCPClient.DoCheckMessage(const ABytes: TBytes;
  const ASize: Integer): Boolean;
begin
  Result := TBenchmark.CheckResponse(ABytes, SizeOf(Integer), ASize - SizeOf(Integer));
end;


begin
  TBenchmark.Run(TTCPClient);
end.
