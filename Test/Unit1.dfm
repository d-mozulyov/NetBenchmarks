object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 387
  ClientWidth = 537
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  PixelsPerInch = 96
  TextHeight = 13
  object Memo1: TMemo
    Left = 0
    Top = 152
    Width = 537
    Height = 235
    Align = alBottom
    ScrollBars = ssBoth
    TabOrder = 0
    WordWrap = False
  end
  object btnSendViaIndy: TButton
    Left = 56
    Top = 41
    Width = 81
    Height = 25
    Caption = 'Send via Indy'
    TabOrder = 1
    OnClick = btnSendViaIndyClick
  end
  object btnSendViaIOCP: TButton
    Left = 56
    Top = 88
    Width = 81
    Height = 25
    Caption = 'Send via IOCP'
    TabOrder = 2
    OnClick = btnSendViaIOCPClick
  end
  object Edit1: TEdit
    Left = 160
    Top = 64
    Width = 289
    Height = 21
    TabOrder = 3
    Text = 'Message Text'
  end
end
