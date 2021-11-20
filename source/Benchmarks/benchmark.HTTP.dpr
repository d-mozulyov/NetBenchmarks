program benchmark.HTTP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    Winapi.Windows,
    Winapi.Winsock2,
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks,
  System.SysUtils;
  

type
  THttpClient = class(TIOCPClient)
  protected
    FIocpConnectEx: TIOCPSocket.TIocpConnectEx;
    FIocpDisconnectEx: TIOCPSocket.TIocpDisconnectEx;

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
    LBuffer := TBenchmark.WORK_REQUEST_UTF8;
  end else
  begin
    LBuffer := 'temp';//TBenchmark.BLANK_REQUEST_UTF8;
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
 // if setsockopt(LSocket.Handle, SOL_SOCKET, $7010{SO_UPDATE_CONNECT_CONTEXT}, nil, 0) <> 0 then
 //   RaiseLastOSError;

  FInBuffer.Overlapped.Event := 0;

  LSocket.GetExtensionFunc(FIocpConnectEx, TIOCPSocket.WSAID_CONNECTEX);
  LSocket.GetExtensionFunc(FIocpDisconnectEx, TIOCPSocket.WSAID_DISCONNECTEX);
end;

procedure THttpClient.DoRun;
var
  Param: Cardinal;
begin
  Param := 0;
//  TIOCPSocket(InObject).Connect();
  if (not FIocpConnectEx({TIOCPSocket.TSocketHandle(}InObject.Handle{)}, PSockAddr(@TIOCPEndpoint.Default.SockAddr),
    SizeOf(TIOCPEndpoint.Default.SockAddr), nil{Pointer(FOutBuffer.Bytes)}, 0{FOutBuffer.Size},
    Param{FInBuffer.Overlapped.InternalSize}, Pointer(@FInBuffer.Overlapped))) and
    (WSAGetLastError <> ERROR_IO_PENDING) then
    RaiseLastOSError;
end;

begin
  TBenchmark.Run(THttpClient);
end.
