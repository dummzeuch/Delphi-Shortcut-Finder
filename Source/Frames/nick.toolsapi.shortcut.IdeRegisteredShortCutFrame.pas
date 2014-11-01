unit nick.toolsapi.shortcut.IdeRegisteredShortCutFrame;

interface

uses
  SysUtils,
  StdCtrls,
  ComCtrls,
  Controls,
  Classes,
  Forms,
  Messages,
  ToolsApi,
  nick.toolsapi.shortcut.IRepositoryFactory,
  nick.toolsapi.shortcut.ISystemRepository,
  nick.toolsapi.shortcut.IFileVersionInformation,
  VirtualTrees,
  Generics.Collections;

type
  TfrmIdeRegisteredShortCut = class(TFrame)
    grpAdvanceFiltering: TGroupBox;
    hkAdvance: THotKey;
    vtShortCutModuleDetails: TVirtualStringTree;
    lblHotkey: TLabel;
    procedure hkAdvanceChange(Sender: TObject);
    procedure vtShortCutModuleDetailsGetText(Sender: TBaseVirtualTree;
                                             Node: PVirtualNode;
                                             Column: TColumnIndex;
                                             TextType: TVSTTextType;
                                             var CellText: string);
  private type
    TModuleDetail = record
      Module : string;
      Path : string;
      ModuleVersion : Pointer;
      FileVersionInformation : IFileVersionInformation;
      KeyBindingRec : TKeyBindingRec;
    end;
  private
    FRepositoryFactory: IRepositoryFactory;
    FModuleDetails : TList<TModuleDetail>;

    procedure ModifyVirtualTree(const AProc : TProc);
    procedure FindModuleDetails(const AKeyBindingRec: TKeyBindingRec;
                                const ASystemRepository: ISystemRepository;
                                const ASnapShotHandle: THandle;
                                var AModuleDetail: TModuleDetail);
    procedure FindShortCutInformation;
  protected
    procedure CMShowingChanged(var M: TMessage); message CM_SHOWINGCHANGED;
  public
    constructor Create(const AOwner: TComponent; const ARepositoryFactory : IRepositoryFactory); reintroduce;
    destructor Destroy; override;
  end;

implementation

uses
  Windows,
  TlHelp32;

{$R *.dfm}

constructor TfrmIdeRegisteredShortCut.Create(const AOwner: TComponent; const ARepositoryFactory: IRepositoryFactory);
begin
  inherited Create(AOwner);
  FRepositoryFactory := ARepositoryFactory;
  FModuleDetails := TList<TModuleDetail>.Create;
end;

destructor TfrmIdeRegisteredShortCut.Destroy;
begin
  FModuleDetails.Free;
  inherited;
end;

procedure TfrmIdeRegisteredShortCut.ModifyVirtualTree(const AProc: TProc);
begin
  vtShortCutModuleDetails.TreeOptions.MiscOptions := vtShortCutModuleDetails.TreeOptions.MiscOptions - [toReadOnly];
  try
    AProc();
  finally
    vtShortCutModuleDetails.TreeOptions.MiscOptions := vtShortCutModuleDetails.TreeOptions.MiscOptions + [toReadOnly];
  end;
end;

procedure TfrmIdeRegisteredShortCut.CMShowingChanged(var M: TMessage);
begin
  inherited;
end;

procedure TfrmIdeRegisteredShortCut.hkAdvanceChange(Sender: TObject);
begin
  FindShortCutInformation();
end;

procedure TfrmIdeRegisteredShortCut.FindModuleDetails(const AKeyBindingRec: TKeyBindingRec;
                                                      const ASystemRepository: ISystemRepository;
                                                      const ASnapShotHandle: THandle;
                                                      var AModuleDetail: TModuleDetail);
var
  LModuleEntry32: TModuleEntry32;
  LValidModuleEntry: Boolean;
begin
  if (ASnapShotHandle = INVALID_HANDLE_VALUE) then
    Exit;

  LModuleEntry32.dwSize := SizeOf(LModuleEntry32);
  LValidModuleEntry := ASystemRepository.Module32First(ASnapShotHandle, LModuleEntry32);
  while LValidModuleEntry do
  begin
    if (NativeUInt(LModuleEntry32.modBaseAddr) <= NativeUInt(@AKeyBindingRec.KeyProc)) and
       (NativeUInt(@AKeyBindingRec.KeyProc) < (NativeUInt(LModuleEntry32.modBaseAddr) + LModuleEntry32.modBaseSize)) then
    begin
      AModuleDetail.Module := LModuleEntry32.szModule;
      AModuleDetail.Path := LModuleEntry32.szExePath;
      break;
    end;
    LValidModuleEntry := ASystemRepository.Module32Next(ASnapShotHandle, LModuleEntry32);
  end;
end;

procedure TfrmIdeRegisteredShortCut.FindShortCutInformation();
var
  LOTAKeyboardServices : IOTAKeyboardServices;
  LSystemRepository : ISystemRepository;
  LKeyBindingRec : TKeyBindingRec;
  LSnapShotHandle : THandle;
  LModuleDetail : TModuleDetail;
begin
  FModuleDetails.Clear;
  try
    if (hkAdvance.HotKey and 255 = 0) then
      Exit;

    if not FRepositoryFactory.ToolsApiRepository().GetKeyboardServices(LOTAKeyboardServices) then
      Exit;

    if not LOTAKeyboardServices.LookupKeyBinding([hkAdvance.HotKey], LKeyBindingRec) then
      Exit;

    LSystemRepository := FRepositoryFactory.SystemRepository();

    LSnapShotHandle := LSystemRepository.CreateToolhelp32Snapshot(TH32CS_SNAPALL, 0);
    try
      repeat
        LModuleDetail.Module := '<unknown>';
        LModuleDetail.Path := '<unknown>';
        LModuleDetail.KeyBindingRec := LKeyBindingRec;

        FindModuleDetails(LKeyBindingRec, LSystemRepository, LSnapShotHandle, LModuleDetail);
        LModuleDetail.FileVersionInformation := LSystemRepository.GetVersionInformation(LModuleDetail.Path);

        FModuleDetails.Add(LModuleDetail);
      until not LOTAKeyboardServices.GetNextBindingRec(LKeyBindingRec);

    finally
      if (LSnapShotHandle <> INVALID_HANDLE_VALUE) then
        LSystemRepository.CloseHandle(LSnapShotHandle);
    end;
  finally
    ModifyVirtualTree(procedure
                      begin
                        vtShortCutModuleDetails.RootNodeCount := 0;
                        vtShortCutModuleDetails.RootNodeCount := FModuleDetails.Count;
                      end);
  end;
end;

procedure TfrmIdeRegisteredShortCut.vtShortCutModuleDetailsGetText(Sender: TBaseVirtualTree;
                                                                   Node: PVirtualNode;
                                                                   Column: TColumnIndex;
                                                                   TextType: TVSTTextType;
                                                                   var CellText: string);
var
  LKeyBindingRec: TKeyBindingRec;
  LModuleDetail : TModuleDetail;
begin
  CellText := '';

  if (not Assigned(Node.Parent)) or (Node.Parent = Sender.RootNode) then
  begin
    if (Column <> 0) then
      Exit;

    CellText := FModuleDetails.Items[Node.Index].FileVersionInformation.FieldString[TVersionInformation.FileDescription];
    if (CellText = EmptyStr) then
      CellText := FModuleDetails.Items[Node.Index].FileVersionInformation.FieldString[TVersionInformation.ProductName];
    if (CellText = EmptyStr) then
      CellText := FModuleDetails.Items[Node.Index].Module;

    ModifyVirtualTree(procedure
                      var
                        LCount : Integer;
                      begin
                        LCount := 4;
                        if (FModuleDetails.Items[Node.Index].FileVersionInformation.HasErrored) or
                           (FModuleDetails.Items[Node.Index].FileVersionInformation.Count = 0) then
                          LCount := 3;

                        Sender.ChildCount[Node] := LCount;
                      end);
    Exit;
  end;

  if (Assigned(Node.Parent.Parent) and (Node.Parent.Parent <> Sender.RootNode)) then
  begin
    // Sub-items..
    LModuleDetail := FModuleDetails.Items[Node.Parent.Parent.Index];
    LKeyBindingRec := LModuleDetail.KeyBindingRec;

    if (Node.Parent.Index = Node.Parent.Parent.ChildCount - 1) then
    begin
      case Column of
        0 : CellText := LModuleDetail.FileVersionInformation.FieldName[Node.Index];
        1 : CellText := LModuleDetail.FileVersionInformation.FieldValue[Node.Index];
      end;
    end
    else if (Node.Parent.Index = Node.Parent.Parent.ChildCount - 2) then
    begin
      case Column of
        0 :
          case Node.Index of
            0 : CellText := 'KeyProc';
            1 : CellText := 'Context';
            2 : CellText := 'Next';
            3 : CellText := 'Reserved';
          end;
        1 :
          case Node.Index of
            0 : CellText := Format('$%p (Code: $%p, Data: $%p)', [@LKeyBindingRec.KeyProc, TMethod(LKeyBindingRec.KeyProc).Code, TMethod(LKeyBindingRec.KeyProc).Data]);
            1 : CellText := Format('$%p', [LKeyBindingRec.Context]);
            2 : CellText := Format('$%0:.8x (%0:d)', [LKeyBindingRec.Next]);
            3 : CellText := Format('$%0:.8x (%0:d)', [LKeyBindingRec.Reserved]);
          end;
      end;
    end;
    Exit;
  end;

  LModuleDetail := FModuleDetails.Items[Node.Parent.Index];

  case Column of
    0 :
      case Node.Index of
        0 : CellText := 'Module';
        1 : CellText := 'Path';
        2 : CellText := 'Advance';
        3 : CellText := 'File Information';
      end;
    1 :
      case Node.Index of
        0 : CellText := LModuleDetail.Module;
        1 : CellText := LModuleDetail.Path;
        2 : ModifyVirtualTree(procedure
                              begin
                                Sender.ChildCount[Node] := 4;
                              end);
        3 : ModifyVirtualTree(procedure
                              begin
                                Sender.ChildCount[Node] := LModuleDetail.FileVersionInformation.Count;
                              end);
      end;
  end;
end;

end.
