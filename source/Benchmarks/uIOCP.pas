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

  TIOCPCallback = function(const AParam: Pointer; const AErrorCode: Integer): Boolean of object;

  PIOCPObject = ^TIOCPObject;
  TIOCPObject = object
    Overlapped: TOverlapped;
    Callback: TIOCPCallback;
  end;

  TIOCPBuffer = object(TIOCPObject)
  private
    function OverflowAlloc(const ASize: Integer): Pointer;
  public
    Bytes: TBytes;
    ReservedSize: Integer;
    Size: Integer;
    Tag: NativeUInt;

    function Alloc(const ASize: Integer; const AAppendMode: Boolean = False): Pointer; inline;
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


{ TIOCPClient class }

  TIOCPClient = class(TClient)
  protected
    class var
      FIOCP: TIOCP;

    class procedure BenchmarkInit; override;
    class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
  protected
    FInBuffer: TIOCPBuffer;
    FOutBuffer: TIOCPBuffer;

    function InBufferCallback(const AParam: Pointer; const AErrorCode: Integer): Boolean; virtual;
    function OutBufferCallback(const AParam: Pointer; const AErrorCode: Integer): Boolean; virtual;
  public
    constructor Create(const AIndex: Integer); override;

    class property IOCP: TIOCP read FIOCP;
    property InBuffer: TIOCPBuffer read FInBuffer;
    property OutBuffer: TIOCPBuffer read FOutBuffer;
  end;


{ TIOCPSocket class }

  TIOCPSocket = class
  public
    type
      {$ifdef MSWINDOWS}
        TSocketHandle = Winapi.WinSock2.TSocket;
      {$else .POSIX}
        TSocketHandle = Integer;
      {$ENDIF}
  protected
    FHandle: TSocketHandle;
    FProtocol: TIOCPProtocol;
  public
    constructor Create(const AProtocol: TIOCPProtocol);
    destructor Destroy; override;

    procedure Connect(const AEndpoint: TIOCPEndpoint);

    property Handle: TSocketHandle read FHandle;
    property Protocol: TIOCPProtocol read FProtocol;
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
    ReservedSize := (Size + 63) and -64;
    SetLength(Bytes, ReservedSize);
  end;

  Result := @Bytes[LOffset];
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


{ TIOCPEndpoint }

class constructor TIOCPEndpoint.ClassCreate;
begin
  Default := TIOCPEndpoint.Create('localhost', TBenchmark.CLIENT_PORT);
end;

constructor TIOCPEndpoint.Create(const AHost: string; const APort: Word);
var
  LAsciiStr: string;
  LHostEnt: PHostEnt;
  LMarshaller: TMarshaller;
begin
  FillChar(FSockAddr, SizeOf(FSockAddr), #0);
  FSockAddr.sin_family := AF_INET;
  FSockAddr.sin_port := htons(APort);

  LHostEnt := nil;
  SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), Length(AHost), nil, 0));
  if Length(LAsciiStr) > 0 then
  begin
    SetLength(LAsciiStr, IdnToAscii(0, PChar(AHost), length(AHost), PChar(LAsciiStr), Length(LAsciiStr)));
    LHostEnt := gethostbyname(LMarshaller.AsAnsi(LAsciiStr).ToPointer);
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
  LIOCPObject: PIOCPObject;
begin
  Result := False;

  repeat
    if GetQueuedCompletionStatus(FHandle, lpNumberOfBytesTransferred,
      ULONG_PTR(LParam), POverlapped(LIOCPObject), 0) then
    begin
      LIOCPObject.Callback(LParam, 0);
      Result := True;
    end else
    if Assigned(LIOCPObject) then
    begin
      LIOCPObject.Callback(LParam, GetLastError);
      Result := True;
    end else
    begin
      Exit;
    end;
  until (False);
end;


{ TIOCPClient }

class procedure TIOCPClient.BenchmarkInit;
begin
  inherited;
  TIOCPClient.FIOCP := TIOCP.Create;
end;

class procedure TIOCPClient.BenchmarkFinal;
begin
  inherited;
  FreeAndNil(TIOCPClient.FIOCP);
end;

class procedure TIOCPClient.BenchmarkProcess;
begin
  inherited;
  TIOCPClient.FIOCP.Process;
end;

constructor TIOCPClient.Create(const AIndex: Integer);
begin
  inherited Create(AIndex);

  FInBuffer.Callback := Self.InBufferCallback;
  FOutBuffer.Callback := Self.OutBufferCallback;
end;

function TIOCPClient.InBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer): Boolean;
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

function TIOCPClient.OutBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer): Boolean;
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





{ TIOCPSocket }

constructor TIOCPSocket.Create(const AProtocol: TIOCPProtocol);
const
  TYPES: array[TIOCPProtocol] of Integer = (SOCK_STREAM, SOCK_DGRAM);
  PROTOCOLS: array[TIOCPProtocol] of Integer = (IPPROTO_TCP, IPPROTO_UDP);
begin
  inherited Create;
  FProtocol := AProtocol;

  FHandle := WSASocket(PF_INET, TYPES[AProtocol], PROTOCOLS[AProtocol], nil, 0, WSA_FLAG_OVERLAPPED);
  if (FHandle = INVALID_SOCKET) then
    RaiseLastOSError;

  TIOCPClient.IOCP.Bind(FHandle, Pointer(Self));
end;

destructor TIOCPSocket.Destroy;
begin
  if (FHandle <> INVALID_SOCKET) then
  begin
    closesocket(FHandle);
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

initialization
  TWSA.Data.wVersion := TWSA.Data.wVersion;

end.
