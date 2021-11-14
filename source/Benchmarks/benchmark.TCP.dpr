program benchmark.TCP;

{$APPTYPE CONSOLE}

uses
  {$ifdef MSWINDOWS}
    uIOCP,
  {$else}
    {$MESSAGE ERROR 'Platform not yet supported'}
  {$endif}
  uBenchmarks;

type
  TTCPClient = class(TIOCPClient)
  protected
    FSocket: TIOCPSocket;

    procedure DoInit; override;
    procedure DoRun; override;
  public
    constructor Create(const AIndex: Integer); override;
    destructor Destroy; override;
  end;
  

{ TTCPClient }

constructor TTCPClient.Create(const AIndex: Integer);
begin
  inherited;
  FSocket := TIOCPSocket.Create(ipTCP);
end;

destructor TTCPClient.Destroy;
begin
  FSocket.Free;
  inherited;
end;

procedure TTCPClient.DoInit;
begin
  FSocket.Connect(TIOCPEndpoint.Default);
end;

procedure TTCPClient.DoRun;
begin


end;


begin
  TBenchmark.Run(TTCPClient);
end.
