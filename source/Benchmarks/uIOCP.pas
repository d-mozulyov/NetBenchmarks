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

    procedure Bind(const AHandle: THandle; const AParam: Pointer);
  end;


  TIOCPClient = class(TClient)
  protected
    class var
      FIOCP: TIOCP;

    class procedure BenchmarkInit; override;
    class procedure BenchmarkFinal; override;
    class procedure BenchmarkProcess; override;
  public

    class property IOCP: TIOCP read FIOCP;
  end;


implementation


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

procedure TIOCP.Bind(const AHandle: THandle; const AParam: Pointer);
begin
  if (CreateIoCompletionPort(AHandle, FHandle, ULONG_PTR(AParam), TIOCP.CPUCount * 2) = 0) then
    RaiseLastOSError;
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

end;

end.
