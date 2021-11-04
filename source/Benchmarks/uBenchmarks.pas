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
    procedure Stop; virtual;

    property WorkMode: Boolean read FWorkMode;
  end;

  TBenchmarkClientClass = class of TBenchmarkClient;


{ TBenchmark class }

  TBenchmark = class
  protected

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

    class constructor ClassCreate;
    class destructor ClassDestroy;
    class procedure InternalLoadJson(const AFileName: string; out AStr: string;
      out AUtf8: UTF8String; out ABytes: TBytes; out ALength: Integer);
  public
    class procedure Run(const AClientClass: TBenchmarkClientClass; const AServerPaths: array of string); virtual;
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
  Stop;
  inherited;
end;

procedure TBenchmarkClient.Init;
begin
end;

procedure TBenchmarkClient.Stop;
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

class procedure TBenchmark.Run(const AClientClass: TBenchmarkClientClass;
  const AServerPaths: array of string);
begin
  Writeln(AClientClass.UnitName, ' running...');

  Write('Press Enter to quit');
  Readln;
end;

initialization
  InitKeyHandler;

end.
