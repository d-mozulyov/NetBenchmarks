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

{ TBenchmarkClient class }

  TBenchmarkClient = class(TObject)
  private
    FWorkMode: Boolean;
  protected
    class procedure BenchmarkInit(const AWorkMode: Boolean); virtual;
    class procedure BenchmarkInitBlank; virtual;
    class procedure BenchmarkInitWork; virtual;

  public
    constructor Create(const AWorkMode: Boolean); virtual;
    destructor Destroy; override;
    procedure Init; virtual;
    procedure Final; virtual;
    procedure Check; virtual;
    procedure Run; virtual;

    property WorkMode: Boolean read FWorkMode;
  end;

  TBenchmarkClientClass = class of TBenchmarkClient;


{ TBenchmark class }

  TBenchmark = class
  protected
    FClientClass: TBenchmarkClientClass;
    FClientCount: Integer;
    FWorkMode: Boolean;
    FAlign: array[1..SizeOf(Integer) - SizeOf(Boolean)] of Byte;
    FClients: TArray<TBenchmarkClient>;
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
    class var
      Instance: TBenchmark;

    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure InternalLoadJson(const AFileName: string; out AStr: string;
      out AUtf8: UTF8String; out ABytes: TBytes; out ALength: Integer);
  public
    constructor Create(const AClientClass: TBenchmarkClientClass; const AClientCount: Integer; const AWorkMode: Boolean); virtual;
    destructor Destroy; override;
    procedure Run; overload;
    class procedure Run(const AClientClass: TBenchmarkClientClass; const AServerPaths: array of string); overload;

    property ClientClass: TBenchmarkClientClass read FClientClass;
    property ClientCount: Integer read FClientCount;
    property WorkMode: Boolean read FWorkMode;
    property Clients: TArray<TBenchmarkClient> read FClients;
  public
    const
      TIMEOUT_SEC = {$ifdef DEBUG}2{$else}10{$endif};
    var
      RequestCount: Integer;
      ResponseCount: Integer;
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


{ TBenchmarkClient }

class procedure TBenchmarkClient.BenchmarkInit(const AWorkMode: Boolean);
begin
  if AWorkMode then
    BenchmarkInitWork
  else
    BenchmarkInitBlank;
end;

class procedure TBenchmarkClient.BenchmarkInitBlank;
begin
end;

class procedure TBenchmarkClient.BenchmarkInitWork;
begin
end;

constructor TBenchmarkClient.Create(const AWorkMode: Boolean);
begin
  inherited Create;
  FWorkMode := AWorkMode;
  Init;
end;

destructor TBenchmarkClient.Destroy;
begin
  Final;
  inherited;
end;

procedure TBenchmarkClient.Init;
begin
end;

procedure TBenchmarkClient.Final;
begin
end;

procedure TBenchmarkClient.Check;
begin

end;

procedure TBenchmarkClient.Run;
begin

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

constructor TBenchmark.Create(const AClientClass: TBenchmarkClientClass;
  const AClientCount: Integer; const AWorkMode: Boolean);
var
  i: Integer;
begin
  inherited Create;
  FClientClass := AClientClass;
  FClientCount := AClientCount;
  FWorkMode := AWorkMode;
  FClientClass.BenchmarkInit(FWorkMode);

  SetLength(FClients, AClientCount);
  FillChar(Pointer(FClients)^, AClientCount * SizeOf(Pointer), #0);
  for i := Low(FClients) to High(FClients) do
    FClients[i] := AClientClass.Create(AWorkMode);
end;

destructor TBenchmark.Destroy;
var
  i: Integer;
begin
  for i := Low(FClients) to High(FClients) do
    FClients[i].Free;

  inherited;
end;

procedure TBenchmark.Run;
var
  i: Integer;
begin
  // initialization
  RequestCount := 0;
  ResponseCount := 0;
  for i := Low(FClients) to High(FClients) do
    FClients[i].Init;

  // running
  // ToDo

  // finalization
  for i := Low(FClients) to High(FClients) do
    FClients[i].Final;
end;

class procedure TBenchmark.Run(const AClientClass: TBenchmarkClientClass;
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

          TBenchmark.Instance := Self.Create(AClientClass, LClientCount, LWorkMode);
          try
            TBenchmark.Instance.Run;
            Writeln(Format('requests: %d, responses: %d, throughput: %d/sec', [
              TBenchmark.Instance.RequestCount, TBenchmark.Instance.ResponseCount,
              Round(TBenchmark.Instance.ResponseCount / TBenchmark.Instance.TIMEOUT_SEC)
            ]));
          finally
            FreeAndNil(TBenchmark.Instance);
          end;
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

initialization
  InitKeyHandler;

end.
