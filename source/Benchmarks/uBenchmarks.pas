unit uBenchmarks;

interface
uses
  {$ifdef MSWINDOWS}
    Winapi.Windows,
    Winapi.ShellApi,
  {$else .POSIX}
  {$endif}
  System.SysUtils,
  System.Classes,
  System.TimeSpan,
  System.Diagnostics,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

type

{ TOSTime record }

  TOSTime = record
  private
    class var
      TIMESTAMP_TICK_UNFREQUENCY: Double;

    class constructor ClassCreate;
  public
    class function GetTimestamp: Cardinal; static; inline;
  end;


{ TSyncYield record }

  TSyncYield = record
  private
    FCount: Byte;
  public
    procedure Reset; inline;
    procedure Execute;

    property Count: Byte read FCount write FCount;
  end;


{ TProcess class }

  TProcess = class
  protected
    {$ifdef MSWINDOWS}
    FHandle: THandle;
    {$endif}
  public
    constructor Create(const APath: string; const AParameters: string = '';
      const ADirectory: string = ''; const AVisible: Boolean = True);
    destructor Destroy; override;

    {$ifdef MSWINDOWS}
    property Handle: THandle read FHandle;
    {$endif}
  end;


{ TStatistics record }

  TStatistics = record
    RequestCount: Integer;
    ResponseCount: Integer;

    class operator Add(const A, B: TStatistics): TStatistics;
  end;


{ TClient class }

  TClient = class(TObject)
  protected
    FStackNext: TClient;
    FStatistics: TStatistics;
    FIndex: Integer;

    class procedure BenchmarkInit; virtual;
    class procedure BenchmarkFinal; virtual;
    class procedure BenchmarkProcess; virtual;
    procedure DoInit; virtual; abstract;
    procedure DoRun; virtual; abstract;
    procedure InternalDoneOSError(const AErrorCode: Integer);
  public
    constructor Create(const AIndex: Integer); virtual;
    procedure Run; inline;
    procedure Done(const AError: string = '');
    procedure DoneOSError(const AErrorCode: Integer); inline;

    property Statistics: TStatistics read FStatistics;
    property RequestCount: Integer read FStatistics.RequestCount;
    property ResponseCount: Integer read FStatistics.ResponseCount;
    property Index: Integer read FIndex;
  end;
  TClientClass = class of TClient;


{ TClientStack record }

  PClientStack = ^TClientStack;
  TClientStack = packed record
    Head: TClient;
    Counter: NativeInt;

    function CmpExchange(const AItem, ANewItem: TClientStack): Boolean; inline;
    procedure PushList(const AFirst, ALast: TClient);
    procedure Push(const AClient: TClient); inline;
    function Pop: TClient;
    function PopAll: TClient;
  end;


{ TBenchmark singleton }

  TBenchmark = record
  public
    const
      CLIENT_PORT = 1234;
      TEXT_CONTENT = 'text/plain';
      JSON_CONTENT = 'application/json';
      BLANK_REQUEST = '';
      BLANK_REQUEST_UTF8: UTF8String = '';
      BLANK_REQUEST_BYTES: TBytes = nil;
      BLANK_REQUEST_LENGHT = 0;
      BLANK_RESPONSE = 'OK';
      BLANK_RESPONSE_UTF8: UTF8String = UTF8String(BLANK_RESPONSE);
      BLANK_RESPONSE_BYTES: TBytes = [Ord('O'), Ord('K')];
      BLANK_RESPONSE_LENGHT = 2;
      CHECK_ERROR = 'Check failure';
      CHECK_ERRORS: array[Boolean] of string = (CHECK_ERROR, '');
    class var
      WORK_REQUEST: string;
      WORK_REQUEST_UTF8: UTF8String;
      WORK_REQUEST_BYTES: TBytes;
      WORK_REQUEST_LENGHT: Integer;
      WORK_RESPONSE: string;
      WORK_RESPONSE_UTF8: UTF8String;
      WORK_RESPONSE_BYTES: TBytes;
      WORK_RESPONSE_LENGHT: Integer;
      CLIENT_STACK_BUFFER: array[0..64 * 2 - 1] of Byte;
    const
      TIMEOUT_SEC = {$ifdef DEBUG}2{$else}10{$endif};
    class var
      ClientCount: Integer;
      Clients: TArray<TClient>;
      ClientStack: PClientStack;
      WorkMode: Boolean;
      CheckMode: Boolean;
      Reserved: Boolean;
      Terminated: Boolean;
      Timestamp: Cardinal;
      Error: string;
  private
    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure InternalLoadJson(const AFileName: string; out AStr: string;
      out AUtf8: UTF8String; out ABytes: TBytes; out ALength: Integer); static;
    class function InternalRun(const AClientClass: TClientClass;
      const AClientCount: Integer; const AWorkMode, ACheckMode: Boolean): TStatistics; static;
  public
    class procedure Run(const AClientClass: TClientClass; const ADefaultMultiThread: Boolean = False); static;
  end;


implementation

{$ifdef MSWINDOWS}
function CtrlHandler(Ctrl: Longint): LongBool; stdcall;
begin
  case (Ctrl) of
    CTRL_C_EVENT,
    CTRL_BREAK_EVENT,
    CTRL_CLOSE_EVENT,
    CTRL_LOGOFF_EVENT,
    CTRL_SHUTDOWN_EVENT:
    begin
      Halt;
    end;
  end;

  Result := True;
end;

procedure InitKeyHandler;
begin
  SetConsoleCtrlHandler(@CtrlHandler, True);
end;
{$else .POSIX}
  // ToDo
procedure InitKeyHandler;
begin
end;
{$endif}


{ TOSTime }

class constructor TOSTime.ClassCreate;
begin
  if TStopwatch.IsHighResolution then
  begin
    TIMESTAMP_TICK_UNFREQUENCY := 10000000.0 / TTimeSpan.TicksPerMillisecond / TStopwatch.Frequency;
  end else
  begin
    TIMESTAMP_TICK_UNFREQUENCY := 1.0 / TTimeSpan.TicksPerMillisecond;
  end;
end;

class function TOSTime.GetTimestamp: Cardinal;
begin
  Result := Round(TIMESTAMP_TICK_UNFREQUENCY * TStopwatch.GetTimeStamp);
end;


{ TSyncYield }

procedure TSyncYield.Reset;
begin
  FCount := 0;
end;

procedure TSyncYield.Execute;
var
  LCount: Integer;
begin
  LCount := FCount;
  FCount := LCount + 1;
  case (LCount and 7) of
    0..4: YieldProcessor;
    5, 6: SwitchToThread;
  else
    Sleep(1);
  end;
end;


{ TProcess }

constructor TProcess.Create(const APath: string; const AParameters: string;
  const ADirectory: string; const AVisible: Boolean);
{$ifdef MSWINDOWS}
const
  VISIBLE_MODES: array[Boolean] of Integer = (SW_HIDE, SW_SHOWDEFAULT);
var
  LShExecInfo: TShellExecuteInfo;
begin
  inherited Create;
  FHandle := INVALID_HANDLE_VALUE;

  FillChar(LShExecInfo, SizeOf(LShExecInfo), #0);
  LShExecInfo.cbSize := SizeOf(LShExecInfo);
  LShExecInfo.fMask := SEE_MASK_NOCLOSEPROCESS;
  LShExecInfo.lpFile := Pointer(APath);
  LShExecInfo.lpParameters := Pointer(AParameters);
  LShExecInfo.lpDirectory := Pointer(ADirectory);
  LShExecInfo.nShow := VISIBLE_MODES[AVisible];
  if ShellExecuteEx(@LShExecInfo) then
    FHandle := LShExecInfo.hProcess
  else
    RaiseLastOSError;
end;
{$else .POSIX}
begin
  inherited Create;
  {$MESSAGE ERROR 'Platform not yet supported'}
end;
{$endif}

destructor TProcess.Destroy;
begin
  {$ifdef MSWINDOWS}
  if FHandle <> INVALID_HANDLE_VALUE then
  begin
    TerminateProcess(FHandle, 0);
    CloseHandle(FHandle);
  end;
  {$else .POSIX}
  {$endif}

  inherited;
end;


{ TStatistics }

class operator TStatistics.Add(const A, B: TStatistics): TStatistics;
begin
  Result.RequestCount := A.RequestCount + B.RequestCount;
  Result.ResponseCount := A.ResponseCount + B.ResponseCount;
end;


{ TClient }

class procedure TClient.BenchmarkInit;
begin
end;

class procedure TClient.BenchmarkFinal;
begin
end;

class procedure TClient.BenchmarkProcess;
begin
end;

constructor TClient.Create(const AIndex: Integer);
begin
  inherited Create;
  FIndex := AIndex;
end;

procedure TClient.Run;
begin
  if (not TBenchmark.Terminated) then
  begin
    Inc(FStatistics.RequestCount);
    DoRun;
  end;
end;

procedure TClient.Done(const AError: string);
begin
  if Assigned(Pointer(AError)) then
  begin
    if TBenchmark.CheckMode then
      TBenchmark.Error := AError;
  end else
  if (not TBenchmark.Terminated) then
  begin
    if TBenchmark.CheckMode then
    begin
      FStatistics.ResponseCount := 1;
      Exit;
    end else
    begin
      Inc(FStatistics.ResponseCount);
    end;
  end;

  TBenchmark.ClientStack.Push(Self);
end;

procedure TClient.InternalDoneOSError(const AErrorCode: Integer);
begin
  Done(SysErrorMessage(AErrorCode));
end;

procedure TClient.DoneOSError(const AErrorCode: Integer);
begin
  if (TBenchmark.CheckMode) then
  begin
    InternalDoneOSError(AErrorCode);
  end else
  begin
    Done('Internal system error');
  end;
end;


{ TClientStack }

function TClientStack.CmpExchange(const AItem, ANewItem: TClientStack): Boolean;
begin
  {$if not Defined(CPUX64) and not Defined(CPUARM64)}
    Result := Int64(AItem) = AtomicCmpExchange(PInt64(@Self)^, Int64(ANewItem), Int64(AItem));
  {$elseif Defined(MSWINDOWS)}
    Result := InterlockedCompareExchange128(@Self, ANewItem.Counter, Int64(ANewItem.Head), @AItem);
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
end;

procedure TClientStack.PushList(const AFirst, ALast: TClient);
var
  LItem, LNewItem: TClientStack;
begin
  if (not System.IsMultiThread) then
  begin
    ALast.FStackNext := Self.Head;
    Self.Head := AFirst;
    Exit;
  end;

  repeat
    LItem := Self;
    LNewItem.Head := AFirst;
    LNewItem.Counter := LItem.Counter + 1;
    ALast.FStackNext := LItem.Head;
  until CmpExchange(LItem, LNewItem);
end;

procedure TClientStack.Push(const AClient: TClient);
begin
  PushList(AClient, AClient);
end;

function TClientStack.Pop: TClient;
var
  LItem, LNewItem: TClientStack;
begin
  if (not System.IsMultiThread) then
  begin
    Result := Self.Head;
    if Assigned(Result) then
    begin
      Self.Head := Result.FStackNext;
    end;
    Exit;
  end;

  repeat
    Result := Self.Head;
    if not Assigned(Result) then
      Exit;

    LItem.Head := Result;
    LItem.Counter := Self.Counter;
    LNewItem.Head := Result.FStackNext;
    LNewItem.Counter := LItem.Counter + 1;
  until CmpExchange(LItem, LNewItem);

  Result := LItem.Head;
end;

function TClientStack.PopAll: TClient;
var
  LItem, LNewItem: TClientStack;
begin
  if (not System.IsMultiThread) then
  begin
    Result := Self.Head;
    Self.Head := nil;
    Exit;
  end;

  repeat
    Result := Self.Head;
    if not Assigned(Result) then
      Exit;

    LItem.Head := Result;
    LItem.Counter := Self.Counter;
    LNewItem.Head := nil;
    LNewItem.Counter := LItem.Counter + 1;
  until CmpExchange(LItem, LNewItem);

  Result := LItem.Head;
end;


{ TBenchmark }

class constructor TBenchmark.ClassCreate;
begin
  SetCurrentDir(ExtractFileDir(ParamStr(0)));

  InternalLoadJson('request.json', WORK_REQUEST, WORK_REQUEST_UTF8,
    WORK_REQUEST_BYTES, WORK_REQUEST_LENGHT);
  InternalLoadJson('response.json', WORK_RESPONSE, WORK_RESPONSE_UTF8,
    WORK_RESPONSE_BYTES, WORK_RESPONSE_LENGHT);

  ClientStack := PClientStack(NativeInt(@CLIENT_STACK_BUFFER[64]) and -64);
end;

class destructor TBenchmark.ClassDestroy;
begin
end;

class procedure TBenchmark.InternalLoadJson(const AFileName: string;
  out AStr: string; out AUtf8: UTF8String; out ABytes: TBytes;
  out ALength: Integer);
var
  LPath: string;
  LValue: TJSONValue;
  LStr: string;
  LBytes: TBytes;
begin
  LPath := '../../source/' + AFileName;
  LValue := TJSONObject.ParseJSONValue(TFile.ReadAllBytes(LPath), 0);
  try
    LStr := LValue.ToString;
    LBytes := TEncoding.UTF8.GetBytes(LStr);

    AStr := LStr;
    AUtf8 := UTF8String(LStr);
    ABytes := LBytes;
    ALength := Length(LBytes);
  finally
    LValue.Free;
  end;
end;

class function TBenchmark.InternalRun(const AClientClass: TClientClass;
  const AClientCount: Integer; const AWorkMode, ACheckMode: Boolean): TStatistics;
var
  i: Integer;
  LSyncYield: TSyncYield;
  LStartTime: Cardinal;
  LCurrentClient, LNextClient: TClient;
begin
  // initialization
  Result := Default(TStatistics);
  TBenchmark.ClientCount := AClientCount;
  SetLength(TBenchmark.Clients, AClientCount);
  FillChar(Pointer(TBenchmark.Clients)^, AClientCount * SizeOf(TClient), #0);
  TBenchmark.WorkMode := AWorkMode;
  TBenchmark.CheckMode := ACheckMode;
  TBenchmark.Terminated := False;
  TBenchmark.Timestamp := TOSTime.GetTimestamp;
  TBenchmark.Error := '';
  try
    AClientClass.BenchmarkInit;

    // clients
    for i := 0 to AClientCount - 1 do
    begin
      TBenchmark.Clients[i] := AClientClass.Create(i);
      if (i > 0) then
      begin
        TBenchmark.Clients[i - 1].FStackNext := TBenchmark.Clients[i];
      end;
      TBenchmark.Clients[i].DoInit;
    end;
    TBenchmark.ClientStack.Head :=  TBenchmark.Clients[0];
    TBenchmark.ClientStack.Counter := 0;

    // process loop
    LSyncYield.Reset;
    Timestamp := TOSTime.GetTimestamp;
    LStartTime := Timestamp;
    while (not Terminated) do
    begin
      AClientClass.BenchmarkProcess;

      // run clients
      LNextClient := TBenchmark.ClientStack.PopAll;
      if Assigned(LNextClient) then
      begin
        LSyncYield.Reset;

        repeat
          LCurrentClient := LNextClient;
          LNextClient := LCurrentClient.FStackNext;
          LCurrentClient.FStackNext := nil;

          LCurrentClient.Run;
        until (not Assigned(LNextClient));
      end else
      begin
        LSyncYield.Execute;
      end;

      // timestamp
      Timestamp := TOSTime.GetTimestamp;

      // is terminated
      if (ACheckMode) then
      begin
        Terminated := (TBenchmark.Clients[0].ResponseCount > 0) or Assigned(Pointer(Error));
        if (not Terminated) and (Cardinal(Timestamp - LStartTime) >= (1000 * 1 {$ifdef NOPROCESS}* 60{$endif})) then
        begin
          Terminated := True;
          Error := 'Timeout error';
        end;
      end else
      begin
        Terminated := (Cardinal(Timestamp - LStartTime) >= (1000 * TIMEOUT_SEC));
      end;
    end;

  finally
    // destroy TBenchmark.Clients
    Terminated := True;
    AClientClass.BenchmarkFinal;
    for i := Low(TBenchmark.Clients) to High(TBenchmark.Clients) do
    begin
      LCurrentClient := TBenchmark.Clients[i];
      if Assigned(LCurrentClient) then
      begin
        Result := Result + LCurrentClient.Statistics;
        LCurrentClient.Free;
      end;
    end;
    TBenchmark.Clients := nil;
  end;
end;

class procedure TBenchmark.Run(const AClientClass: TClientClass; const ADefaultMultiThread: Boolean);
const
  CLIENT_COUNTS: TArray<Integer> = [1, 100, 10000];
  WORK_MODES: TArray<Boolean> = [{$ifNdef NOPROCESS}False,{$endif} True];
  WORK_MODE_STRS: array[Boolean] of string = ('blank', 'work');
var
  P: Integer;
  S: string;
  LProtocol: string;
  LServerPathArr: TArray<string>;
  LClientCountArr: TArray<Integer>;
  LWorkModeArr: TArray<Boolean>;
  LServerPath: string;
  LClientCount: Integer;
  LWorkMode: Boolean;
  LServerName: string;
  LProcessPath: string;
  LProcessParameters: string;
  LProcessProcess: TProcess;
  LStatistics: TStatistics;
begin
  // multi-thread
  System.IsMultiThread := System.IsMultiThread or ADefaultMultiThread;

  // protocol
  LProtocol := StringReplace(AClientClass.UnitName, 'benchmark.', '', [rfReplaceAll, rfIgnoreCase]);

  // parameters
  begin
    S := ParamStr(1);
    if (S <> '') then
    begin
      LServerPathArr := [S];
    end else
    if (LProtocol = 'Pipe') then
    begin
      LServerPathArr := ['node ../../source/Node.js/Node.Pipe.js'];
    end else
    begin
      LServerPathArr := ['Indy.' + LProtocol];
    end;

    S := ParamStr(2);
    if TryStrToInt(S, LClientCount) and (LClientCount > 0) then
    begin
      LClientCountArr := [LClientCount];
    end else
    begin
      LClientCountArr := CLIENT_COUNTS;
    end;

    S := ParamStr(3);
    if (S = '0') or (S = '1') then
    begin
      LWorkModeArr := [S = '1'];
    end else
    begin
      LWorkModeArr := WORK_MODES;
    end;
  end;

  for LServerPath in LServerPathArr do
  begin
    Writeln;
    {$ifdef DEBUG}
    Writeln('DEBUG mode');
    {$endif}

    try
      for LClientCount in LClientCountArr do
      for LWorkMode in LWorkModeArr do
      begin
        LServerName := StringReplace(LServerPath, '.js', '', [rfReplaceAll]);
        repeat
          P := Pos('/', LServerName);
          if (P = 0) then
            Break;

          Delete(LServerName, 1, P);
        until (False);
        Write(Format('%s %d con %s... ', [LServerName, LClientCount, WORK_MODE_STRS[LWorkMode]]));

        if (Copy(LServerPath, 1, 5) = 'node ') then
        begin
          LProcessPath := 'node';
          LProcessParameters := Copy(LServerPath, 6, High(Integer)) + ' ' + IntToStr(Byte(LWorkMode));
        end else
        begin
          LProcessPath := LServerPath;
          LProcessParameters := IntToStr(Byte(LWorkMode));
        end;
        {$ifdef MSWINDOWS}
        LProcessPath := LProcessPath + '.exe';
        {$endif}
        LProcessProcess := {$ifdef NOPROCESS}nil{$else}TProcess.Create(LProcessPath, LProcessParameters, '', False){$endif};
        try
          Sleep({$ifdef DEBUG}500{$else}1000{$endif});

          // check
          TBenchmark.InternalRun(AClientClass, 1, LWorkMode, True);
          if Assigned(Pointer(TBenchmark.Error)) then
            raise Exception.CreateFmt('%s', [TBenchmark.Error]);

          // run benchmark
          LStatistics := TBenchmark.InternalRun(AClientClass, LClientCount, LWorkMode, False);
          Writeln(Format('requests: %d, responses: %d, throughput: %d/sec', [
              LStatistics.RequestCount, LStatistics.ResponseCount,
              Round(LStatistics.ResponseCount / TBenchmark.TIMEOUT_SEC)
            ]));
        finally
          LProcessProcess.Free;
        end;
      end;
    except
      on E: Exception do
      begin
        if E.ClassType = Exception then
        begin
          Writeln(E.Message);
        end else
        begin
          Writeln(E.ClassName, ': ', E.Message);
        end;
      end;
    end;
  end;

  {$WARNINGS OFF}
  if (System.DebugHook <> 0) then
  begin
    Write('Press Enter to quit');
    Readln;
  end;
  {$WARNINGS ON}
end;


initialization
  InitKeyHandler;

end.
