unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  IdGlobal, IdContext, IdTCPClient, IdTCPServer, Winapi.Winsock2;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    btnSendViaIndy: TButton;
    btnSendViaIOCP: TButton;
    Edit1: TEdit;
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure btnSendViaIndyClick(Sender: TObject);
    procedure btnSendViaIOCPClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FTCPServer: TIdTCPServer;
    FTCPClient: TIdTCPClient;
    FIOCPHandle: THandle;
    FSocketHandle: Winapi.Winsock2.TSocket;

    procedure DoServerExecute(AContext: TIdContext);
    function PackMessage: TIdBytes;
  public
    { Public declarations }
  end;

const
  SERVER_HOST: string = '127.0.0.1';
  SERVER_PORT = 4321;

var
  WsaData: TWsaData;
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
var
  LSockAddr: TSockAddrIn;
  LAsciiStr: string;
  LAnsiStr: AnsiString;
  LHostEnt: PHostEnt;
begin
  FTCPServer := TIdTCPServer.Create(nil);
  FTCPServer.OnExecute := DoServerExecute;
  FTCPServer.Bindings.Add.Port := SERVER_PORT;
  FTCPServer.Active := True;

  FTCPClient := TIdTCPClient.Create(nil);
  FTCPClient.Connect(SERVER_HOST, SERVER_PORT);

  FIOCPHandle := CreateIoCompletionPort(INVALID_HANDLE_VALUE, 0, 0, System.CPUCount);
  if (FIOCPHandle = 0) then
    RaiseLastOSError;

  FillChar(LSockAddr, SizeOf(LSockAddr), #0);
  LSockAddr.sin_family := AF_INET;
  LSockAddr.sin_port := htons(SERVER_PORT);
  LHostEnt := nil;
  SetLength(LAsciiStr, IdnToAscii(0, PChar(SERVER_HOST), Length(SERVER_HOST), nil, 0));
  if Length(LAsciiStr) > 0 then
  begin
    SetLength(LAsciiStr, IdnToAscii(0, PChar(SERVER_HOST), Length(SERVER_HOST), PChar(LAsciiStr), Length(LAsciiStr)));
    LAnsiStr := AnsiString(LAsciiStr);
    LHostEnt := gethostbyname(Pointer(LAnsiStr));
  end;
  if Assigned(LHostEnt) then
    LSockAddr.sin_addr.s_addr := PCardinal(LHostEnt.h_addr_list^)^;

  FSocketHandle := WSASocket(PF_INET, SOCK_STREAM, IPPROTO_TCP, nil, 0, WSA_FLAG_OVERLAPPED);
  if (FSocketHandle= INVALID_SOCKET) then
    RaiseLastOSError;
  if (CreateIoCompletionPort(FSocketHandle, FIOCPHandle, 0, System.CPUCount) = 0) then
    RaiseLastOSError;
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
  shutdown(FSocketHandle, SD_BOTH);
  closesocket(FSocketHandle);
  CloseHandle(FIOCPHandle);
  FTCPClient.Free;
  FTCPServer.Free;
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TForm1.DoServerExecute(AContext: TIdContext);
var
  LSize: Cardinal;
  LBuffer: TIdBytes;
  LValue: UTF8String;
begin
  LSize := AContext.Connection.Socket.ReadUInt32(False);
  if (LSize <> 0) then
  begin
    SetLength(LBuffer, LSize);
    AContext.Connection.Socket.ReadBytes(LBuffer, LSize, False);
  end;

  SetLength(LValue, LSize);
  Move(Pointer(LBuffer)^, Pointer(LValue)^, LSize);

  TThread.Synchronize(nil,
    procedure
    begin
      Memo1.Lines.Add(string(LValue));
    end);
end;

function TForm1.PackMessage: TIdBytes;
var
  LSize: Cardinal;
  LValue: UTF8String;
begin
  LValue := UTF8String(Edit1.Text);
  LSize := Length(LValue);
  SetLength(Result, SizeOf(Cardinal) + LSize);
  PCardinal(Result)^ := LSize;
  Move(Pointer(LValue)^, Result[SizeOf(Cardinal)], LSize);
end;

procedure TForm1.btnSendViaIndyClick(Sender: TObject);
begin
  FTCPClient.IOHandler.Write(PackMessage);
end;

procedure TForm1.btnSendViaIOCPClick(Sender: TObject);
begin
//
end;


initialization
  WSAStartup(WINSOCK_VERSION, WsaData);

finalization
  WSACleanup;

end.
