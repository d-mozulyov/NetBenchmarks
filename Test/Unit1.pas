unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  IdGlobal, IdContext, IdTCPClient, IdTCPServer;

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

    procedure DoServerExecute(AContext: TIdContext);
  public
    { Public declarations }
  end;

const
  SERVER_PORT = 4321;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
  FTCPServer := TIdTCPServer.Create(nil);
  FTCPServer.OnExecute := DoServerExecute;
  FTCPServer.Bindings.Add.Port := SERVER_PORT;
  FTCPServer.Active := True;


end;

procedure TForm1.FormDestroy(Sender: TObject);
begin


  FTCPServer.Free;
//
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
  LSize := AContext.Connection.Socket.ReadUInt32;
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

procedure TForm1.btnSendViaIndyClick(Sender: TObject);
var
  LSize: Cardinal;
  LValue: UTF8String;
  LBuffer: TIdBytes;
  LClient: TIdTCPClient;
begin
  LValue := UTF8String(Edit1.Text);
  LSize := Length(LValue);
  SetLength(LBuffer, LSize);
  Move(Pointer(LValue)^, Pointer(LBuffer)^, LSize);

  LClient := TIdTCPClient.Create(nil);
  try
    LClient.Connect('127.0.0.1', SERVER_PORT);
    LClient.IOHandler.Write(LSize);
    LClient.IOHandler.Write(LBuffer);
  finally
    LClient.Free;
  end;
end;

procedure TForm1.btnSendViaIOCPClick(Sender: TObject);
begin
//
end;

end.
