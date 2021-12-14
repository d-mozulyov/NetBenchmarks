unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls;

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
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

procedure TForm1.FormCreate(Sender: TObject);
begin
//
end;

procedure TForm1.FormDestroy(Sender: TObject);
begin
//
end;

procedure TForm1.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
    Close;
end;

procedure TForm1.btnSendViaIndyClick(Sender: TObject);
begin
//
end;

procedure TForm1.btnSendViaIOCPClick(Sender: TObject);
begin
//
end;

end.
