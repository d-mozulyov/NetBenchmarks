unit uServers;

interface
uses
  {$ifdef MSWINDOWS}
    Winapi.Windows,
  {$else .POSIX}
  {$endif}
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON;


var
  WORK_MODE: Boolean = False;

const
  SERVER_PORT = 1234;
  TEXT_CONTENT = 'text/plain';
  JSON_CONTENT = 'application/json';
  BLANK_RESPONSE = 'OK';
  BLANK_RESPONSE_UTF8: UTF8String = UTF8String(BLANK_RESPONSE);
  BLANK_RESPONSE_BYTES: TBytes = [Ord('O'), Ord('K')];


procedure LogServerListening(const AServer: TObject);
procedure SleepLoop;

procedure ProcessJson(const ATargetJson, ASourceJson: TJSONObject); overload;
function ProcessJson(const AJson: TJSONObject): string; overload;
function ProcessJson(const AStream: TStream): string; overload;
function ProcessJson(const AJson: string): string; overload;
function ProcessJson(const AJson: TBytes): TBytes; overload;

implementation

var
  Terminated: Boolean = False;

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
      Terminated := True;
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

procedure LogServerListening(const AServer: TObject);
const
  MODES: array[Boolean] of string = ('blank', 'work');
begin
  Write(AServer.UnitName, ' (', MODES[WORK_MODE], ' mode) port ', SERVER_PORT, ' listening...');
end;

procedure SleepLoop;
begin
  while (not Terminated) do
  begin
    Sleep(1000);
  end;
end;

(* Request:
{
	"product": "test",
	"requestId": "{BC6B8989-DAB7-484E-9AD3-F7C34A800A1A}",
	"group": {
				"kind": "clients",
				"default": true,
				"balance": 109240.59,
				"dates": [
					"2020-01-12T10:53:17.773Z",
					"2020-11-10T06:47:04.462Z",
					"2020-01-01T00:00:00.007Z",
					"2020-03-14T22:36:33.316Z",
					"2020-04-09T14:47:25.082Z",
					"2020-09-02T03:41:33.744Z",
					"2020-04-26T07:44:07.926Z",
					"2020-02-29T01:19:41.793Z",
					"2020-05-15T20:48:28.880Z",
					"2020-06-04T08:54:07.931Z"
				]
			}
}*)

(* Response:
{
	"product": "test",
	"requestId": "{BC6B8989-DAB7-484E-9AD3-F7C34A800A1A}",
	"client": {
				"balance": 109240.59,
				"minDate": "2020-01-01T00:00:00.007Z",
				"maxDate": "2020-11-10T06:47:04.462Z"
			}
}*)

procedure ProcessJson(const ATargetJson, ASourceJson: TJSONObject);
var
  i: Integer;
  LClient, LGroup: TJSONObject;
  LDates: TJSONArray;
  LDate: TDateTime;
  LMinDate, LMaxDate: TDateTime;

  function InternalStrToDateTime(const AValue: string): TDateTime;
  var
    LYear, LMonth, LDay, LHour, LMinute, LSecond, LMillisecond: Word;
  begin
    LYear        := StrToInt(Copy(AValue, 1, 4));
    LMonth       := StrToInt(Copy(AValue, 6, 2));
    LDay         := StrToInt(Copy(AValue, 9, 2));
    LHour        := StrToInt(Copy(AValue, 12, 2));
    LMinute      := StrToInt(Copy(AValue, 15, 2));
    LSecond      := StrToInt(Copy(AValue, 18, 2));
    LMillisecond := StrToInt(Copy(AValue, 21, 3));

    Result := EncodeDate(LYear, LMonth, LDay) + EncodeTime(LHour, LMinute, LSecond, LMillisecond);
  end;

  function InternalDateTimeToStr(const AValue: TDateTime): string;
  begin
    Result := FormatDateTime('yyyy-mm-dd', AValue) + 'T' +
      FormatDateTime('hh:mm:ss.zzz', AValue) + 'Z';
  end;
begin
  LGroup := ASourceJson.GetValue('group') as TJSONObject;
  ATargetJson.AddPair('product', ASourceJson.GetValue('product').Clone as TJsonValue);
  ATargetJson.AddPair('requestId', ASourceJson.GetValue('requestId').Clone as TJsonValue);

  LDates := LGroup.GetValue('dates') as TJSONArray;
  LMinDate := MaxDateTime;
  LMaxDate := MinDateTime;
  for i := 0 to LDates.Count - 1 do
  begin
    LDate := InternalStrToDateTime((LDates.Items[i] as TJSONString).Value);
    if (LDate < LMinDate) then LMinDate := LDate;
    if (LDate > LMaxDate) then LMaxDate := LDate;
  end;

  LClient := TJSONObject.Create;
  ATargetJson.AddPair('client', LClient);
  LClient.AddPair('balance', LGroup.GetValue('balance').Clone as TJsonValue);
  LClient.AddPair('minDate', InternalDateTimeToStr(LMinDate));
  LClient.AddPair('maxDate', InternalDateTimeToStr(LMaxDate));
end;

function ProcessJson(const AJson: TJSONObject): string;
var
  LTargetJson: TJSONObject;
begin
  LTargetJson := TJSONObject.Create;
  try
    ProcessJson(LTargetJson, AJson);
    Result := LTargetJson.ToString;
  finally
    LTargetJson.Free;
  end;
end;

function ProcessJson(const AStream: TStream): string;
var
  LBuffer: TBytes;
  LCount: NativeUInt;
  LValue: TJSONValue;
begin
  LCount := AStream.Size;
  SetLength(LBuffer, LCount);
  AStream.ReadBuffer(Pointer(LBuffer)^, LCount);

  LValue := TJSONObject.ParseJSONValue(LBuffer, 0);
  try
    Result := ProcessJson(LValue as TJSONObject);
  finally
    LValue.Free;
  end;
end;

function ProcessJson(const AJson: string): string;
var
  LValue: TJSONValue;
begin
  LValue := TJSONObject.ParseJSONValue(AJson);
  try
    Result := ProcessJson(LValue as TJSONObject);
  finally
    LValue.Free;
  end;
end;

function ProcessJson(const AJson: TBytes): TBytes;
var
  LTargetJson: TJSONObject;
  LSourceJson: TJSONValue;
begin
  LTargetJson := TJSONObject.Create;
  try
    LSourceJson := TJSONObject.ParseJSONValue(AJson, 0);
    try
      ProcessJson(LTargetJson, LSourceJson as TJSONObject);
    finally
      LSourceJson.Free;
    end;

    SetLength(Result, LTargetJson.EstimatedByteSize);
    SetLength(Result, LTargetJson.ToBytes(Result, 0));
  finally
    LTargetJson.Free;
  end;
end;


initialization
  InitKeyHandler;
  if (ParamStr(1) = '1') then
  begin
    WORK_MODE := True;
  end;

end.
