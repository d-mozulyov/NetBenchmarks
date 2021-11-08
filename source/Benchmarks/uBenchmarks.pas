unit uBenchmarks;

interface
uses
  {$ifdef MSWINDOWS}
    Winapi.Windows,
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
    FWorkMode: Boolean;
    FCheckMode: Boolean;

    class procedure BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean); virtual;
    class procedure BenchmarkFinal(const AClientCount: Integer; const AWorkMode: Boolean); virtual;
    class procedure BenchmarkGCRun; virtual;
    class function BenchmarkGCTimeOut: Cardinal; virtual;
    procedure DoRun; virtual; abstract;
    procedure DoInit; virtual; abstract;
  public
    constructor Create(const AIndex: Integer; const AWorkMode, ACheckMode: Boolean); virtual;
    procedure Run; inline;
    procedure Done(const AError: PWideChar = nil);

    property Statistics: TStatistics read FStatistics;
    property RequestCount: Integer read FStatistics.RequestCount;
    property ResponseCount: Integer read FStatistics.ResponseCount;
    property Index: Integer read FIndex;
    property WorkMode: Boolean read FWorkMode;
    property CheckMode: Boolean read FCheckMode;
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
      Error: PChar;
      Timestamp: Cardinal;
      Terminated: Boolean;
  private
    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure InternalLoadJson(const AFileName: string; out AStr: string;
      out AUtf8: UTF8String; out ABytes: TBytes; out ALength: Integer); static;
    class function InternalRun(const AClientClass: TClientClass;
      const AClientCount: Integer; const AWorkMode, ACheckMode: Boolean): TStatistics; static;
  public
    class procedure Run(const AClientClass: TClientClass); static;
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


{ TStatistics }

class operator TStatistics.Add(const A, B: TStatistics): TStatistics;
begin
  Result.RequestCount := A.RequestCount + B.RequestCount;
  Result.ResponseCount := A.ResponseCount + B.ResponseCount;
end;


{ TClient }

class procedure TClient.BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean);
begin
end;

class procedure TClient.BenchmarkFinal(const AClientCount: Integer; const AWorkMode: Boolean);
begin
end;

class procedure TClient.BenchmarkGCRun;
begin
end;

class function TClient.BenchmarkGCTimeOut: Cardinal;
begin
  Result := 0;
end;

constructor TClient.Create(const AIndex: Integer; const AWorkMode, ACheckMode: Boolean);
begin
  inherited Create;
  FIndex := AIndex;
  FWorkMode := AWorkMode;
  FCheckMode := ACheckMode;
end;

procedure TClient.Run;
begin
  if (not TBenchmark.Terminated) then
  begin
    Inc(FStatistics.RequestCount);
    DoRun;
  end;
end;

procedure TClient.Done(const AError: PWideChar);
begin
  if Assigned(AError) then
  begin
    if CheckMode then
      TBenchmark.Error := AError;
  end else
  if (not TBenchmark.Terminated) then
  begin
    if CheckMode then
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
  LGCTimeOut, LGCLastTime: Cardinal;
  LCurrentClient, LNextClient: TClient;
begin
  Result := Default(TStatistics);
  Timestamp := TOSTime.GetTimestamp;
  AClientClass.BenchmarkInit(AClientCount, AWorkMode);
  try
    // GC timeout
    LGCTimeOut := AClientClass.BenchmarkGCTimeOut;

    // create clients
    ClientCount := AClientCount;
    SetLength(Clients, ClientCount);
    FillChar(Pointer(Clients)^, ClientCount * SizeOf(Pointer), #0);
    for i := 0 to ClientCount - 1 do
      Clients[i] := AClientClass.Create(i, AWorkMode, ACheckMode);

    // initialize clients
    ClientStack.Head := Clients[0];
    ClientStack.Counter := 0;
    for i := 0 to ClientCount - 1 do
    begin
      if (i <> ClientCount - 1) then
      begin
        Clients[i].FStackNext := Clients[i + 1];
      end;
      Clients[i].DoInit;
    end;

    // process loop
    Error := nil;
    Terminated := False;
    LSyncYield.Reset;
    Timestamp := TOSTime.GetTimestamp;
    LStartTime := Timestamp;
    LGCLastTime := Timestamp;
    while (not Terminated) do
    begin
      // check GC timeout
      if (LGCTimeOut <> 0) and (Cardinal(Timestamp - LGCLastTime) >= LGCTimeOut) then
      begin
        LGCLastTime := Timestamp;
        AClientClass.BenchmarkGCRun;
      end;

      // running clients
      LNextClient := ClientStack.PopAll;
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
        Terminated := (Clients[0].ResponseCount > 0) or Assigned(Error);
        if (not Terminated) and (Cardinal(Timestamp - LStartTime) >= (1000 * 1)) then
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
    // destroy clients
    Terminated := True;
    AClientClass.BenchmarkFinal(AClientCount, AWorkMode);
    for i := Low(Clients) to High(Clients) do
    begin
      Result := Result + Clients[i].Statistics;
      FreeAndNil(Clients[i]);
    end;
    Clients := nil;
  end;
end;

class procedure TBenchmark.Run(const AClientClass: TClientClass);
const
  CLIENT_COUNTS: TArray<Integer> = [1, 100, 10000];
  WORK_MODES: TArray<Boolean> = [False, True];
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
  LStatistics: TStatistics;
begin
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

        {ToDo запуск сервера}

        try
          Sleep({$ifdef DEBUG}500{$else}1000{$endif});

          // check
          TBenchmark.Error := nil;
          TBenchmark.InternalRun(AClientClass, 1, LWorkMode, True);
          if Assigned(TBenchmark.Error) then
            raise Exception.CreateFmt('%s', [TBenchmark.Error]);

          // run benchmark
          LStatistics := TBenchmark.InternalRun(AClientClass, LClientCount, LWorkMode, False);
          Writeln(Format('requests: %d, responses: %d, throughput: %d/sec', [
              LStatistics.RequestCount, LStatistics.ResponseCount,
              Round(LStatistics.ResponseCount / TBenchmark.TIMEOUT_SEC)
            ]));
        finally
          {ToDo остановить сервер}
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
