unit uIOCP;

interface
uses
  Winapi.Windows,
  Winapi.Winsock2,
  System.SysUtils,
  System.Classes,
  uBenchmarks;


{
  POverlapped = ^TOverlapped;
  _OVERLAPPED = record
    Internal: ULONG_PTR;
    InternalHigh: ULONG_PTR;
    Offset: DWORD;
    OffsetHigh: DWORD;
    hEvent: THandle;
  end;

function GetOverlappedResult(hFile: THandle; const lpOverlapped: TOverlapped;
  var lpNumberOfBytesTransferred: DWORD; bWait: BOOL): BOOL; stdcall;
function GetOverlappedResultEx(hFile: THandle; lpOverlapped: TOverlapped;
  var lpNumberOfBytesTransferred: DWORD; dwMilliseconds: DWORD; bAlertable: Boolean): ByteBool; stdcall;
function CreateIoCompletionPort(FileHandle, ExistingCompletionPort: THandle;
  CompletionKey: ULONG_PTR; NumberOfConcurrentThreads: DWORD): THandle; stdcall;
function GetQueuedCompletionStatus(CompletionPort: THandle;
  var lpNumberOfBytesTransferred: DWORD; var lpCompletionKey: ULONG_PTR;
  var lpOverlapped: POverlapped; dwMilliseconds: DWORD): BOOL; stdcall;
function GetQueuedCompletionStatusEx(CompletionPort: THandle; var lpCompletionPortEntries: TOverlappedEntry;
  ulCount: Cardinal; var ulNumEntriesRemoved: Cardinal; dwMilliseconds: DWORD; fAlertable: Boolean): ByteBool; stdcall;
function PostQueuedCompletionStatus(CompletionPort: THandle; dwNumberOfBytesTransferred: DWORD;
  dwCompletionKey: UIntPtr; lpOverlapped: POverlapped): BOOL; stdcall;
}

type

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



implementation


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

end.
