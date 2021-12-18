unit uIOCP;

interface
uses
  Winapi.Windows,
  Winapi.Winsock2,
  System.SysUtils,
  System.Classes,
  uBenchmarks;


type

{ WSA intiialization/finalization }

  TWSA = record
  class var
    Data: WSAData;
    class constructor ClassCreate;
    class destructor ClassDestroy;
  end;


{ IOCP routine }

  TIOCPCallback = procedure(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt) of object;

  PIOCPOverlapped = ^TIOCPOverlapped;
  TIOCPOverlapped = object
    Internal: TOverlapped;
    InternalBuf: TWsaBuf;
    InternalSize: Cardinal;
    InternalFlags: Cardinal;
    Callback: TIOCPCallback;

    property Event: THandle read Internal.hEvent write Internal.hEvent;
    property Ptr: MarshaledAString read InternalBuf.buf write InternalBuf.buf;
    property Size: u_long read InternalBuf.len write InternalBuf.len;
  end;

  TIOCPBuffer = object
  private
    function OverflowAlloc(const ASize: Integer): Pointer;
  public
    Overlapped: TIOCPOverlapped;
    Bytes: TBytes;
    ReservedSize: Integer;
    Size: Integer;
    Tag: NativeUInt;

    procedure Reserve(const ASize: Integer);
    function Alloc(const ASize: Integer; const AAppendMode: Boolean = False): Pointer; inline;
    procedure WriteInteger(const AValue: Integer; const AAppendMode: Boolean = False); inline;
    procedure WriteBytes(const AValue: TBytes; const AAppendMode: Boolean = False);
  end;

  TIOCPProtocol = (ipTCP, ipUDP);

  TIOCPEndpoint = record
  private
    class var
      FDefault: TIOCPEndpoint;
    class constructor ClassCreate;
  public
    SockAddr: TSockAddrIn;

    constructor Create(const AHost: string; const APort: Word);
    class property Default: TIOCPEndpoint read FDefault;
  end;

  TIOCP = class
  protected
    class var
      CPUCount: Integer;

    class constructor ClassCreate;
  protected
    FHandle: THandle;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Bind(const AItemHandle: THandle; const AParam: Pointer = nil);
    function Process: Boolean;
  end;


{ TIOCPObject = class }

  TIOCPObject = class
  protected
    FIOCP: TIOCP;
    FHandle: THandle;
    FHandleOwner: Boolean;
  public
    constructor Create(const AIOCP: TIOCP; const AHandle: THandle; const AHandleOwner: Boolean);
    destructor Destroy; override;

    procedure OverlappedWrite(var AOverlapped: TIOCPOverlapped); overload; virtual; abstract;
    procedure OverlappedRead(var AOverlapped: TIOCPOverlapped); overload; virtual; abstract;
    procedure OverlappedWrite(var ABuffer: TIOCPBuffer); overload;
    procedure OverlappedRead(var ABuffer: TIOCPBuffer); overload;

    property IOCP: TIOCP read FIOCP;
    property Handle: THandle read FHandle;
  end;


{ TIOCPSocket class }

  TIOCPSocket = class(TIOCPObject)
  public
    type
      {$ifdef MSWINDOWS}
        TSocketHandle = Winapi.WinSock2.TSocket;
      {$else .POSIX}
        TSocketHandle = Cardinal;
      {$ENDIF}
      TIocpAcceptEx = function(sListenSocket, sAccepTSocketHandle: TSocketHandle; lpOutputBuffer: Pointer; dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD; var lpdwBytesReceived: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
      TIocpConnectEx = function(const s: TSocketHandle; const name: PSockAddr; const namelen: Integer; lpSendBuffer: Pointer; dwSendDataLength: DWORD; var lpdwBytesSent: DWORD; lpOverlapped: POverlapped): BOOL; stdcall;
      TIocpGetAcceptExSockAddrs = procedure(lpOutputBuffer: Pointer; dwReceiveDataLength, dwLocalAddressLength, dwRemoteAddressLength: DWORD; var LocalSockaddr: PSockAddr; var LocalSockaddrLength: Integer; var RemoteSockaddr: PSockAddr; var RemoteSockaddrLength: Integer); stdcall;
      TIocpDisconnectEx = function(const hSocket: TSocketHandle; lpOverlapped: POverlapped; const dwFlags: DWORD; const dwReserved: DWORD): BOOL; stdcall;
    const
      WSAID_ACCEPTEX: TGUID = (D1: $b5367df1; D2: $cbac; D3: $11cf; D4: ($95, $ca, $00, $80, $5f, $48, $a1, $92));
      WSAID_CONNECTEX: TGUID = (D1: $25a207b9; D2: $ddf3; D3: $4660; D4: ($8e, $e9, $76, $e5, $8c, $74, $06, $3e));
      WSAID_GETACCEPTEXSOCKADDRS: TGUID = (D1: $b5367df2; D2: $cbac; D3: $11cf; D4: ($95, $ca, $00, $80, $5f, $48, $a1, $92));
      WSAID_DISCONNECTEX: TGUID = (D1: $7fda2e11; D2: $8630; D3: $436f; D4: ($a0, $31, $f5, $36, $a6, $ee, $c1, $57));
  protected
    FProtocol: TIOCPProtocol;
  public
    constructor Create(const AProtocol: TIOCPProtocol); overload;
    constructor Create(const AIOCP: TIOCP; const AProtocol: TIOCPProtocol); overload;
    destructor Destroy; override;
    procedure GetExtensionFunc(var AFunc; const AId: TGUID);

    procedure Connect(const AEndpoint: TIOCPEndpoint); overload;
    procedure Connect; overload; inline;
    procedure Disconnect;

    procedure OverlappedWrite(var AOverlapped: TIOCPOverlapped); override;
    procedure OverlappedRead(var AOverlapped: TIOCPOverlapped); override;

    property Protocol: TIOCPProtocol read FProtocol;
  end;


{ TIOCPPipe class }

  TIOCPPipe = class(TIOCPObject)
  protected
  public
    // ToDo
  end;


{ TIOCPClient class }

  TIOCPClient = class(TClient)
  protected
    class var
      FPrimaryIOCP: TIOCP;
      FDefaultOutMessage: TBytes;

    class function BenchmarkDefaultOutMessage: TBytes; virtual;
    class procedure BenchmarkInit; override;
    class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
  protected
    FInBuffer: TIOCPBuffer;
    FOutBuffer: TIOCPBuffer;
    FInObject: TIOCPObject;
    FInObjectOwner: Boolean;
    FOutObject: TIOCPObject;
    FOutObjectOwner: Boolean;

    procedure CleanupObjects; virtual;
    function DoGetMessageSize(const ABytes: TBytes; const ASize: Integer): Integer; virtual;
    function DoCheckMessage(const ABytes: TBytes; const ASize: Integer): Boolean; virtual;
    procedure InBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt);
    procedure OutBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt);
  public
    constructor Create(const AIndex: Integer); override;
    destructor Destroy; override;

    procedure InitObjects(const AInOutObject: TIOCPObject; const AInOutObjectOwner: Boolean); overload; inline;
    procedure InitObjects(const AInObject: TIOCPObject; const AInObjectOwner: Boolean;
      const AOutObject: TIOCPObject; const AOutObjectOwner: Boolean); overload;

    class property PrimaryIOCP: TIOCP read FPrimaryIOCP;
    class property DefaultOutMessage: TBytes read FDefaultOutMessage;
    property InBuffer: TIOCPBuffer read FInBuffer;
    property OutBuffer: TIOCPBuffer read FOutBuffer;
    property InObject: TIOCPObject read FInObject;
    property InObjectOwner: Boolean read FInObjectOwner;
    property OutObject: TIOCPObject read FOutObject;
    property OutObjectOwner: Boolean read FOutObjectOwner;
  end;


implementation


{ TWSA }

class constructor TWSA.ClassCreate;
begin
  WSAStartup(WINSOCK_VERSION, TWSA.Data);
end;

class destructor TWSA.ClassDestroy;
begin
  WSACleanup;
end;


{ TIOCPBuffer }

function TIOCPBuffer.OverflowAlloc(const ASize: Integer): Pointer;
var
  LOffset: Integer;
begin
  LOffset := Size - ASize;
  if (Size > ReservedSize) then
  begin
    Reserve(Size);
  end;

  Result := @Bytes[LOffset];
end;

procedure TIOCPBuffer.Reserve(const ASize: Integer);
var
  LReservedSize: Integer;
begin
  if (ASize >= Size) then
  begin
    LReservedSize := (ASize + 63) and -64;
    if (LReservedSize <> ReservedSize) then
    begin
      SetLength(Bytes, LReservedSize);
      ReservedSize := LReservedSize;
    end;
  end;
end;

function TIOCPBuffer.Alloc(const ASize: Integer; const AAppendMode: Boolean): Pointer;
var
  LNewSize: Integer;
begin
  if (not AAppendMode) then
  begin
    LNewSize := ASize;
    Size := LNewSize;
    if LNewSize <= ReservedSize then
    begin
      Result := Pointer(Bytes);
      Exit;
    end;
  end else
  begin
    LNewSize := Size + ASize;
    Size := LNewSize;
    if LNewSize <= ReservedSize then
    begin
      Result := @Bytes[LNewSize - ASize];
      Exit;
    end;
  end;

  Result := OverflowAlloc(ASize);
end;

procedure TIOCPBuffer.WriteInteger(const AValue: Integer; const AAppendMode: Boolean);
begin
  PInteger(Alloc(SizeOf(Integer), AAppendMode))^ := AValue;
end;

procedure TIOCPBuffer.WriteBytes(const AValue: TBytes; const AAppendMode: Boolean);
var
  LSize: Integer;
begin
  LSize := Length(AValue);
  WriteInteger(LSize, AAppendMode);
  Move(Pointer(AValue)^, Alloc(LSize)^, LSize);
end;


{ TIOCPEndpoint }

class constructor TIOCPEndpoint.ClassCreate;
begin
  FDefault := TIOCPEndpoint.Create('localhost', TBenchmark.CLIENT_PORT);
end;

constructor TIOCPEndpoint.Create(const AHost: string; const APort: Word);
var
  LAsciiStr: string;
  LAnsiStr: AnsiString;
  LHostEnt: PHostEnt;
begin
  FillChar(SockAddr, SizeOf(SockAddr), #0);
  SockAddr.sin_family := AF_INET;
  SockAddr.sin_port := htons(APort);

  LHostEnt := nil;
  SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), Length(AHost), nil, 0));
  if Length(LAsciiStr) > 0 then
  begin
    SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), Length(AHost), PChar(LAsciiStr), Length(LAsciiStr)));
    LAnsiStr := AnsiString(LAsciiStr);
    LHostEnt := gethostbyname(Pointer(LAnsiStr));
  end;
  if Assigned(LHostEnt) then
    SockAddr.sin_addr.s_addr := PCardinal(LHostEnt.h_addr_list^)^;
end;


{ TIOCP }

class constructor TIOCP.ClassCreate;
var
  i: Integer;
  LSize, LCount: Integer;
  LBuffer: array of TSystemLogicalProcessorInformation;
begin
  LSize := 0;
  GetLogicalProcessorInformation(nil, Pointer(@LSize));
  LCount := LSize div SizeOf(TSystemLogicalProcessorInformation);
  SetLength(LBuffer, LCount);
  if not GetLogicalProcessorInformation(Pointer(LBuffer), Pointer(@LSize)) then
    RaiseLastOSError;

  for i := 0 to LCount - 1 do
  case LBuffer[i].Relationship of
    RelationProcessorCore: Inc(TIOCP.CPUCount);
  end;

  if TIOCP.CPUCount = 0 then
    TIOCP.CPUCount := System.CPUCount;
end;

constructor TIOCP.Create;
begin
  inherited Create;
  FHandle := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, TIOCP.CPUCount * 2);
  if (FHandle = 0) then
    RaiseLastOSError;
end;

destructor TIOCP.Destroy;
begin
  if FHandle <> 0 then
  begin
    CloseHandle(FHandle);
  end;

  inherited;
end;

procedure TIOCP.Bind(const AItemHandle: THandle; const AParam: Pointer);
begin
  if (CreateIoCompletionPort(AItemHandle, FHandle, ULONG_PTR(AParam), TIOCP.CPUCount * 2) = 0) then
    RaiseLastOSError;
end;

function TIOCP.Process: Boolean;
var
  lpNumberOfBytesTransferred: DWORD;
  LParam: Pointer;
  LIOCPOverlapped: PIOCPOverlapped;
begin
  Result := False;

  repeat
    if GetQueuedCompletionStatus(FHandle, lpNumberOfBytesTransferred,
      ULONG_PTR(LParam), POverlapped(LIOCPOverlapped), 0) then
    begin
      LIOCPOverlapped.Callback(LParam, 0, lpNumberOfBytesTransferred);
      Result := True;
    end else
    if Assigned(LIOCPOverlapped) then
    begin
      LIOCPOverlapped.Callback(LParam, GetLastError, lpNumberOfBytesTransferred);
      Result := True;
    end else
    begin
      Exit;
    end;
  until (False);
end;


{ TIOCPObject }

constructor TIOCPObject.Create(const AIOCP: TIOCP; const AHandle: THandle; const AHandleOwner: Boolean);
begin
  inherited Create;

  FIOCP := AIOCP;
  FHandle := AHandle;
  FHandleOwner := AHandleOwner;

  FIOCP.Bind(FHandle, Pointer(Self));
end;

destructor TIOCPObject.Destroy;
begin
  if FHandleOwner and (FHandle <> 0) and (FHandle <> INVALID_HANDLE_VALUE) then
  begin
    if not CloseHandle(FHandle) then
      RaiseLastOSError;
  end;

  inherited;
end;

procedure TIOCPObject.OverlappedWrite(var ABuffer: TIOCPBuffer);
begin
  ABuffer.Overlapped.InternalBuf.buf := Pointer(ABuffer.Bytes);
  ABuffer.Overlapped.InternalBuf.len := ABuffer.Size;
  OverlappedWrite(ABuffer.Overlapped);
end;

procedure TIOCPObject.OverlappedRead(var ABuffer: TIOCPBuffer);
begin
  ABuffer.Overlapped.InternalBuf.buf := Pointer(@ABuffer.Bytes[ABuffer.Size]);
  ABuffer.Overlapped.InternalBuf.len := ABuffer.ReservedSize - ABuffer.Size;
  OverlappedRead(ABuffer.Overlapped);
end;


{ TIOCPSocket }

constructor TIOCPSocket.Create(const AProtocol: TIOCPProtocol);
begin
  Create(TIOCPClient.PrimaryIOCP, AProtocol);
end;

constructor TIOCPSocket.Create(const AIOCP: TIOCP; const AProtocol: TIOCPProtocol);
const
  TYPES: array[TIOCPProtocol] of Integer = (SOCK_STREAM, SOCK_DGRAM);
  PROTOCOLS: array[TIOCPProtocol] of Integer = (IPPROTO_TCP, IPPROTO_UDP);
var
  LHandle: TSocketHandle;
begin
  FProtocol := AProtocol;

  LHandle := WSASocket(PF_INET, TYPES[AProtocol], PROTOCOLS[AProtocol], nil, 0, WSA_FLAG_OVERLAPPED);
  if (LHandle = TSocketHandle(INVALID_SOCKET)) then
    RaiseLastOSError;

  inherited Create(AIOCP, LHandle, True);
end;

destructor TIOCPSocket.Destroy;
var
  LHandle: TSocketHandle;
begin
  LHandle := TSocketHandle(FHandle);
  FHandle := 0;
  if (FHandleOwner) and (LHandle <> 0) and (LHandle <> INVALID_SOCKET) then
  begin
    shutdown(FHandle, SD_BOTH);
    closesocket(LHandle);
  end;

  inherited;
end;

procedure TIOCPSocket.GetExtensionFunc(var AFunc; const AId: TGUID);
var
  LCode: Integer;
  LTemp: Cardinal;
begin
  LCode := WSAIoctl(TSocketHandle(FHandle), SIO_GET_EXTENSION_FUNCTION_POINTER,
    @AId, SizeOf(AId), @AFunc, SizeOf(Pointer), LTemp, nil, nil);
  if (LCode <> 0) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.Connect(const AEndpoint: TIOCPEndpoint);
begin
  if (WSAConnect(FHandle, PSockAddr(@AEndpoint.SockAddr)^, SizeOf(AEndpoint.SockAddr),
    nil, nil, nil, nil) <> 0) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.Connect;
begin
  Connect(TIOCPEndpoint.Default);
end;

procedure TIOCPSocket.Disconnect;
begin
  if (shutdown(FHandle, SD_BOTH) <> 0) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.OverlappedWrite(var AOverlapped: TIOCPOverlapped);
var
  LWSAOverlapped: PWSAOverlapped;
begin
  LWSAOverlapped := nil;
  if (AOverlapped.Event <> 1) then
    LWSAOverlapped := PWSAOverlapped(@AOverlapped.Internal);

  if (WSASend(FHandle, @AOverlapped.InternalBuf, 1, AOverlapped.InternalSize, 0,
    LWSAOverlapped, nil) < 0) and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.OverlappedRead(var AOverlapped: TIOCPOverlapped);
var
  LWSAOverlapped: PWSAOverlapped;
begin
  LWSAOverlapped := nil;
  if (AOverlapped.Event <> 1) then
    LWSAOverlapped := PWSAOverlapped(@AOverlapped.Internal);

  AOverlapped.InternalFlags := 0;
  if (WSARecv(FHandle, @AOverlapped.InternalBuf, 1, AOverlapped.InternalSize, AOverlapped.InternalFlags,
    LWSAOverlapped, nil) < 0) and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;


{ TIOCPClient }

class function TIOCPClient.BenchmarkDefaultOutMessage: TBytes;
begin
  Result := nil;
end;

class procedure TIOCPClient.BenchmarkInit;
begin
  inherited;
  TIOCPClient.FPrimaryIOCP := TIOCP.Create;
  TIOCPClient.FDefaultOutMessage := BenchmarkDefaultOutMessage;
end;

class procedure TIOCPClient.BenchmarkFinal;
begin
  inherited;
  FreeAndNil(TIOCPClient.FPrimaryIOCP);
  TIOCPClient.FDefaultOutMessage := nil;
end;

class procedure TIOCPClient.BenchmarkProcess;
begin
  inherited;
  TIOCPClient.FPrimaryIOCP.Process;
end;

constructor TIOCPClient.Create(const AIndex: Integer);
begin
  inherited;

  FInBuffer.Overlapped.Callback := Self.InBufferCallback;
  FInBuffer.Reserve(1024);
  FInBuffer.Overlapped.InternalBuf.buf := Pointer(FInBuffer.Bytes);
  FInBuffer.Overlapped.InternalBuf.len := FInBuffer.ReservedSize;

  FOutBuffer.Overlapped.Callback := Self.OutBufferCallback;
  if Assigned(TIOCPClient.FDefaultOutMessage) then
  begin
    FOutBuffer.Bytes := TIOCPClient.FDefaultOutMessage;
    FOutBuffer.ReservedSize := Length(FOutBuffer.Bytes);
    FOutBuffer.Size := FOutBuffer.ReservedSize;
  end else
  begin
    FOutBuffer.Reserve(FInBuffer.ReservedSize);
  end;
  FOutBuffer.Overlapped.InternalBuf.buf := Pointer(FOutBuffer.Bytes);
  FOutBuffer.Overlapped.InternalBuf.len := FOutBuffer.Size;
end;

destructor TIOCPClient.Destroy;
begin
  CleanupObjects;
  inherited;
end;

procedure TIOCPClient.CleanupObjects;
begin
  if (FInObject = FOutObject) then
  begin
    FOutObject := nil;
    if (FInObjectOwner) then
      FreeAndNil(FInObject)
    else
      FInObject := nil;
  end else
  try
    if (FInObjectOwner) then
      FreeAndNil(FInObject)
    else
      FInObject := nil;
  finally
    if (FOutObjectOwner) then
      FreeAndNil(FOutObject)
    else
      FOutObject := nil;
  end;
end;

procedure TIOCPClient.InitObjects(const AInOutObject: TIOCPObject; const AInOutObjectOwner: Boolean);
begin
  InitObjects(AInOutObject, AInOutObjectOwner, AInOutObject, False);
end;

procedure TIOCPClient.InitObjects(const AInObject: TIOCPObject; const AInObjectOwner: Boolean;
  const AOutObject: TIOCPObject; const AOutObjectOwner: Boolean);
begin
  try
    CleanupObjects;
  finally
    FInObject := AInObject;
    FInObjectOwner := AInObjectOwner;
    FOutObject := AOutObject;
    FOutObjectOwner := AOutObjectOwner;
  end;
end;

function TIOCPClient.DoGetMessageSize(const ABytes: TBytes; const ASize: Integer): Integer;
begin
  Result := ASize;
end;

function TIOCPClient.DoCheckMessage(const ABytes: TBytes; const ASize: Integer): Boolean;
begin
  Result := False;
end;

procedure TIOCPClient.InBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt);
var
  LMessageSize: Integer;
  LDone: Boolean;
begin
  if AErrorCode = 0 then
  begin
    Inc(FInBuffer.Size, ASize);
    LMessageSize := DoGetMessageSize(FInBuffer.Bytes, FInBuffer.Size);

    if LMessageSize <= FInBuffer.Size then
    begin
      LDone := (not TBenchmark.CheckMode) or (DoCheckMessage(FInBuffer.Bytes, LMessageSize));

      if LMessageSize <> 0 then
      begin
        if LMessageSize = FInBuffer.Size then
        begin
          FInBuffer.Size := 0;
        end else
        begin
          Move(FInBuffer.Bytes[FInBuffer.Size], FInBuffer.Bytes[0], FInBuffer.Size - LMessageSize);
          Dec(FInBuffer.Size, LMessageSize);
        end;
      end;

      if LDone then
      begin
        Done;
      end else
      begin
        Done(TBenchmark.CHECK_ERROR);
      end;
    end else
    begin
      if (LMessageSize > FInBuffer.ReservedSize) then
      begin
        FInBuffer.Reserve(LMessageSize);
      end;

      InObject.OverlappedRead(FInBuffer);
    end;
  end else
  begin
    DoneOSError(AErrorCode);
  end;
end;

procedure TIOCPClient.OutBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt);
begin
  if AErrorCode <> 0 then
  begin
    DoneOSError(AErrorCode);
  end;
end;


initialization
  TWSA.Data.wVersion := TWSA.Data.wVersion;

end.
