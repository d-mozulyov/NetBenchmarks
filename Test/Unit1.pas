unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  IdGlobal, IdContext, IdTCPClient, IdTCPServer, Winapi.Winsock2;

type
  TIOCPCallback = function(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean of object;

  PIOCPOverlapped = ^TIOCPOverlapped;
  TIOCPOverlapped = object
    Internal: TOverlapped;
    InternalBuf: TWsaBuf;
    InternalSize: Cardinal;
    InternalFlags: Cardinal;
    Callback: TIOCPCallback;

    property Event: THandle read Internal.hEvent write Internal.hEvent;
    property Ptr: MarshaledAString read InternalBuf.buf write InternalBuf.buf;
    property Size: u_long read InternalBuf.len write InternalBuf.len;
  end;

  TIOCPBuffer = object
  private
    function OverflowAlloc(const ASize: Integer): Pointer;
  public
    Overlapped: TIOCPOverlapped;
    Bytes: TBytes;
    ReservedSize: Integer;
    Size: Integer;
    Tag: NativeUInt;

    procedure Reserve(const ASize: Integer);
    function Alloc(const ASize: Integer; const AAppendMode: Boolean = False): Pointer; inline;
    procedure WriteInteger(const AValue: Integer; const AAppendMode: Boolean = False); inline;
    procedure WriteBytes(const AValue: TBytes; const AAppendMode: Boolean = False);
  end;

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
    FMessage: TIdBytes;
    FWsaBuf: TWsaBuf;
    FInBuffer: TIOCPBuffer;
    FOutBuffer: TIOCPBuffer;

    procedure DoServerExecute(AContext: TIdContext);
    function PackMessage: TIdBytes;
    function InBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
    function OutBufferCallback(const AParam: Pointer; const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
    procedure OverlappedWrite(var AOverlapped: TIOCPOverlapped);
    procedure OverlappedRead(var AOverlapped: TIOCPOverlapped);
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

{ TIOCPBuffer }

function TIOCPBuffer.OverflowAlloc(const ASize: Integer): Pointer;
var
  LOffset: Integer;
begin
  LOffset := Size - ASize;
  if (Size > ReservedSize) then
  begin
    Reserve(Size);
  end;

  Result := @Bytes[LOffset];
end;

procedure TIOCPBuffer.Reserve(const ASize: Integer);
var
  LReservedSize: Integer;
begin
  if (ASize >= Size) then
  begin
    LReservedSize := (ASize + 63) and -64;
    if (LReservedSize <> ReservedSize) then
    begin
      SetLength(Bytes, LReservedSize);
      ReservedSize := LReservedSize;
    end;
  end;
end;

function TIOCPBuffer.Alloc(const ASize: Integer; const AAppendMode: Boolean): Pointer;
var
  LNewSize: Integer;
begin
  if (not AAppendMode) then
  begin
    LNewSize := ASize;
    Size := LNewSize;
    if LNewSize <= ReservedSize then
    begin
      Result := Pointer(Bytes);
      Exit;
    end;
  end else
  begin
    LNewSize := Size + ASize;
    Size := LNewSize;
    if LNewSize <= ReservedSize then
    begin
      Result := @Bytes[LNewSize - ASize];
      Exit;
    end;
  end;

  Result := OverflowAlloc(ASize);
end;

procedure TIOCPBuffer.WriteInteger(const AValue: Integer; const AAppendMode: Boolean);
begin
  PInteger(Alloc(SizeOf(Integer), AAppendMode))^ := AValue;
end;

procedure TIOCPBuffer.WriteBytes(const AValue: TBytes; const AAppendMode: Boolean);
var
  LSize: Integer;
begin
  LSize := Length(AValue);
  WriteInteger(LSize, AAppendMode);
  Move(Pointer(AValue)^, Alloc(LSize)^, LSize);
end;

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
  if (WSAConnect(FSocketHandle, PSockAddr(@LSockAddr)^, SizeOf(LSockAddr),
    nil, nil, nil, nil) <> 0) then
    RaiseLastOSError;

  FInBuffer.Overlapped.Callback := Self.InBufferCallback;
  FInBuffer.Reserve(1024);
  FInBuffer.Overlapped.InternalBuf.buf := Pointer(FInBuffer.Bytes);
  FInBuffer.Overlapped.InternalBuf.len := FInBuffer.ReservedSize;

  FOutBuffer.Overlapped.Callback := Self.OutBufferCallback;
  FOutBuffer.Overlapped.Event := 1;
  FOutBuffer.Reserve(FInBuffer.ReservedSize);
  FOutBuffer.Overlapped.InternalBuf.buf := Pointer(FOutBuffer.Bytes);
  FOutBuffer.Overlapped.InternalBuf.len := FOutBuffer.Size;
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

function TForm1.InBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
begin
  Result := True;
end;

function TForm1.OutBufferCallback(const AParam: Pointer;
  const AErrorCode: Integer; const ASize: NativeUInt): Boolean;
begin
  Result := True;
end;

procedure TForm1.OverlappedWrite(var AOverlapped: TIOCPOverlapped);
begin
  if (WSASend(FSocketHandle, @AOverlapped.InternalBuf, 1, AOverlapped.InternalSize, 0,
    PWSAOverlapped(@AOverlapped.Internal), nil) < 0) and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;

procedure TForm1.OverlappedRead(var AOverlapped: TIOCPOverlapped);
begin
  AOverlapped.InternalFlags := 0;
  if (WSARecv(FSocketHandle, @AOverlapped.InternalBuf, 1, AOverlapped.InternalSize, AOverlapped.InternalFlags,
    PWSAOverlapped(@AOverlapped.Internal), nil) < 0) and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError;
end;

procedure TForm1.btnSendViaIndyClick(Sender: TObject);
begin
  FTCPClient.IOHandler.Write(PackMessage);
end;

procedure TForm1.btnSendViaIOCPClick(Sender: TObject);
begin
  FOutBuffer.WriteBytes(TBytes(PackMessage));
  OverlappedWrite(FOutBuffer.Overlapped);

(*  FWsaBuf.buf := Pointer(FMessage);
  FWsaBuf.len := Length(FMessage);
  LByteCount := FWsaBuf.len;
  if (WSASend(FSocketHandle, @FWsaBuf, 1, LByteCount, 0,
    Pointer(@FOutBuffer), nil) < 0) and (WSAGetLastError <> WSA_IO_PENDING) then
    RaiseLastOSError; *)
end;


initialization
  WSAStartup(WINSOCK_VERSION, WsaData);

finalization
  WSACleanup;

end.
