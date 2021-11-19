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

  TIOCPCallback = function(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean of object;

  PIOCPOverlapped = ^TIOCPOverlapped;
  TIOCPOverlapped = object
    Internal: TOverlapped;
    InternalBuf: TWsaBuf;
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
    FSockAddr: TSockAddrIn;
    class constructor ClassCreate;
  public
    class var
      Default: TIOCPEndpoint;

    constructor Create(const AHost: string; const APort: Word);
    property SockAddr: TSockAddrIn read FSockAddr;
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
  protected
    FProtocol: TIOCPProtocol;
  public
    constructor Create(const AProtocol: TIOCPProtocol); overload;
    constructor Create(const AIOCP: TIOCP; const AProtocol: TIOCPProtocol); overload;
    destructor Destroy; override;

    procedure Connect(const AEndpoint: TIOCPEndpoint);
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


{ TCustomIOCPClient class }

  TCustomIOCPClient = class(TClient)
  protected
    class var
      FPrimaryIOCP: TIOCP;

    class procedure BenchmarkInit; override;
    class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
  protected
    FInBuffer: TIOCPBuffer;
    FOutBuffer: TIOCPBuffer;

//    procedure DoRun; override;
    function DoCheck(const ABuffer: TIOCPBuffer): Boolean; virtual;
    function InBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean; virtual;
    function OutBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean; virtual;
  public
    constructor Create(const AIndex: Integer); override;

    class property PrimaryIOCP: TIOCP read FPrimaryIOCP;
    property InBuffer: TIOCPBuffer read FInBuffer;
    property OutBuffer: TIOCPBuffer read FOutBuffer;
  end;


{ TIOCPClient class }

  TIOCPClient = class(TCustomIOCPClient)
  public
    constructor Create(const AIndex: Integer); override;
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
  Default := TIOCPEndpoint.Create('localhost', TBenchmark.CLIENT_PORT);
end;

constructor TIOCPEndpoint.Create(const AHost: string; const APort: Word);
var
  LAsciiStr: string;
  LAnsiStr: AnsiString;
  LHostEnt: PHostEnt;
begin
  FillChar(FSockAddr, SizeOf(FSockAddr), #0);
  FSockAddr.sin_family := AF_INET;
  FSockAddr.sin_port := htons(APort);

  LHostEnt := nil;
  SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), Length(AHost), nil, 0));
  if Length(LAsciiStr) > 0 then
  begin
    SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), Length(AHost), PChar(LAsciiStr), Length(LAsciiStr)));
    LAnsiStr := AnsiString(LAsciiStr);
    LHostEnt := gethostbyname(Pointer(LAnsiStr));
  end;
  if Assigned(LHostEnt) then
    FSockAddr.sin_addr.s_addr := PCardinal(LHostEnt.h_addr_list^)^;
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
  // ToDo
end;

procedure TIOCPObject.OverlappedRead(var ABuffer: TIOCPBuffer);
begin
  // ToDo
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

  inherited Create(AIOCP, LHandle, True);;
end;

destructor TIOCPSocket.Destroy;
var
  LHandle: TSocketHandle;
begin
  LHandle := TSocketHandle(FHandle);
  FHandle := 0;
  if (FHandleOwner) and (LHandle <> 0) and (LHandle <> INVALID_SOCKET) then
  begin
    closesocket(LHandle);
  end;

  inherited;
end;

procedure TIOCPSocket.Connect(const AEndpoint: TIOCPEndpoint);
var
  LSockAddr: TSockAddrIn;
begin
  LSockAddr := AEndpoint.SockAddr;
  if (Winapi.Winsock2.connect(FHandle, PSockAddr(@LSockAddr)^, SizeOf(LSockAddr)) <> 0) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.OverlappedWrite(var AOverlapped: TIOCPOverlapped);
var
  LBytes, LFlags: Cardinal;
begin
  LFlags := 0;
  LBytes := 0;
  if (WSASend(FHandle, @AOverlapped.InternalBuf, 1, LBytes, LFlags, PWSAOverlapped(@AOverlapped.Internal), nil) < 0)
    and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;

procedure TIOCPSocket.OverlappedRead(var AOverlapped: TIOCPOverlapped);
var
  LBytes, LFlags: Cardinal;
begin
  LFlags := 0;
  LBytes := 0;
  if (WSARecv(FHandle, @AOverlapped.InternalBuf, 1, LBytes, LFlags, PWSAOverlapped(@AOverlapped.Internal), nil) < 0)
    and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;


{ TCustomIOCPClient }

class procedure TCustomIOCPClient.BenchmarkInit;
begin
  inherited;
  TCustomIOCPClient.FPrimaryIOCP := TIOCP.Create;
end;

class procedure TCustomIOCPClient.BenchmarkFinal;
begin
  inherited;
  FreeAndNil(TCustomIOCPClient.FPrimaryIOCP);
end;

class procedure TCustomIOCPClient.BenchmarkProcess;
begin
  inherited;
  TCustomIOCPClient.FPrimaryIOCP.Process;
end;

constructor TCustomIOCPClient.Create(const AIndex: Integer);
begin
  inherited Create(AIndex);

  FInBuffer.Reserve(1024);
  FInBuffer.Overlapped.Callback := Self.InBufferCallback;
  FOutBuffer.Reserve(1024);
  FOutBuffer.Overlapped.Callback := Self.OutBufferCallback;
end;

function TCustomIOCPClient.DoCheck(const ABuffer: TIOCPBuffer): Boolean;
begin
  Result := True;
end;

function TCustomIOCPClient.InBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
begin
  if AErrorCode = 0 then
  begin
    Inc(FInBuffer.Size, ASize);

    if (not TBenchmark.CheckMode) or DoCheck(FInBuffer) then
    begin
      Done;
      Result := True;
    end else
    begin
      Done(TBenchmark.CHECK_ERROR);
      Result := True;
    end;
  end else
  begin
    DoneOSError(AErrorCode);
    Result := False;
  end;
end;

function TCustomIOCPClient.OutBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
begin
  if AErrorCode = 0 then
  begin
    Result := True;
  end else
  begin
    DoneOSError(AErrorCode);
    Result := False;
  end;
end;


{ TIOCPClient }

constructor TIOCPClient.Create(const AIndex: Integer);
begin
  inherited;

  FInBuffer.Reserve(1024);
  FOutBuffer.Reserve(FInBuffer.ReservedSize);
  FOutBuffer.Overlapped.Event := 1;
end;


initialization
  TWSA.Data.wVersion := TWSA.Data.wVersion;

end.
