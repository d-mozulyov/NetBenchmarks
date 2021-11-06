unit uBenchmarks;

interface
uses
  {$ifdef MSWINDOWS}
    Winapi.Windows,
  {$else .POSIX}
  {$endif}
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON;

type

(*
    Типичная картина наиболее сложного протокола: UDPx2





*)

  TClient = class;
  TClientClass = class of TClient;


{ TClientStack }

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
    const
      TIMEOUT_SEC = {$ifdef DEBUG}2{$else}10{$endif};
    class var
      ClientCount: Integer;
      Clients: TArray<TClient>;
      RequestCount: Integer;
      ResponseCount: Integer;
      Error: PChar;
      Terminated: Boolean;

  private
    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure InternalLoadJson(const AFileName: string; out AStr: string;
      out AUtf8: UTF8String; out ABytes: TBytes; out ALength: Integer); static;
    class procedure InternalRun(const AClientClass: TClientClass;
      const AClientCount: Integer; const AWorkMode, ACheckMode: Boolean); static;
  public
    class procedure Run(const AClientClass: TClientClass; const AServerPaths: array of string); static;
  end;


{ TClient class }

  TClient = class(TObject)
  private
    FStackNext: TClient;
    FIndex: Integer;
    FWorkMode: Boolean;
    FCheckMode: Boolean;
  protected
    class procedure BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean); virtual;
    procedure DoRun; virtual; abstract;
  public
    constructor Create(const AIndex: Integer; const AWorkMode, ACheckMode: Boolean); virtual;
    procedure Run; inline;
    procedure Done(const AError: PWideChar = nil);

    property Index: Integer read FIndex;
    property WorkMode: Boolean read FWorkMode;
    property CheckMode: Boolean read FCheckMode;
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
  InternalLoadJson('request.json', WORK_REQUEST, WORK_REQUEST_UTF8,
    WORK_REQUEST_BYTES, WORK_REQUEST_LENGHT);
  InternalLoadJson('response.json', WORK_RESPONSE, WORK_RESPONSE_UTF8,
    WORK_RESPONSE_BYTES, WORK_RESPONSE_LENGHT);
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

class procedure TBenchmark.InternalRun(const AClientClass: TClientClass;
  const AClientCount: Integer; const AWorkMode, ACheckMode: Boolean);
var
  i: Integer;
begin
  // create clients
  ClientCount := AClientCount;
  SetLength(Clients, ClientCount);
  for i := 0 to ClientCount - 1 do
    Clients[i] := AClientClass.Create(i, AWorkMode, ACheckMode);

  try



  finally
    // destroy clients
    for i := Low(Clients) to High(Clients) do
      Clients[i].Free;


  end;
end;

class procedure TBenchmark.Run(const AClientClass: TClientClass;
  const AServerPaths: array of string);
const
  CLIENT_COUNTS: array of Integer = [1, 100, 10000];
  WORK_MODES: array of Boolean = [False, True];
  WORK_MODE_STRS: array[Boolean] of string = ('blank', 'work');
var
  P: Integer;
  LServerPath: string;
  LClientCount: Integer;
  LWorkMode: Boolean;
  LServerName: string;
begin
  Writeln(StringReplace(AClientClass.UnitName, 'benckmark.', '', [rfReplaceAll, rfIgnoreCase]),
    ' Server benchmark running...');

  for LServerPath in AServerPaths do
  begin
    Writeln;

    try
      for LClientCount in CLIENT_COUNTS do
      for LWorkMode in WORK_MODES do
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

          // initialization
          AClientClass.BenchmarkInit(LClientCount, LWorkMode);

          // check
          TBenchmark.Error := nil;
          TBenchmark.InternalRun(AClientClass, 1, LWorkMode, True);
          if Assigned(TBenchmark.Error) then
            raise Exception.CreateFmt('%s', [TBenchmark.Error]);

          // run benchmark
          TBenchmark.InternalRun(AClientClass, LClientCount, LWorkMode, False);
          Writeln(Format('requests: %d, responses: %d, throughput: %d/sec', [
              TBenchmark.RequestCount, TBenchmark.ResponseCount,
              Round(TBenchmark.ResponseCount / TBenchmark.TIMEOUT_SEC)
            ]));
        finally
          {ToDo остановить сервер}
        end;
      end;
    except
      on E: Exception do
        Writeln(E.ClassName, ': ', E.Message);
    end;
  end;

  {$ifdef DEBUG}
  Write('Press Enter to quit');
  Readln;
  {$endif}
end;


{ TClient }

class procedure TClient.BenchmarkInit(const AClientCount: Integer; const AWorkMode: Boolean);
begin
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
    AtomicIncrement(TBenchmark.RequestCount);
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
    AtomicIncrement(TBenchmark.ResponseCount);
  end;

  // ToDo
end;


initialization
  InitKeyHandler;

end.
