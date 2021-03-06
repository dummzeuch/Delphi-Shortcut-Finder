unit nick.shortcut.element.CnWizards;

interface

implementation

uses
  nick.shortcut.builder.ShortCutItem,
  nick.shortcut.builder.IShortCutItem,
  nick.shortcut.repository.IRegistry,
  nick.shortcut.repository.ShortCut,
  nick.shortcut.repository.IToolsApi,
  nick.shortcut.repository.ISystem,
  nick.shortcut.repository.IXmlFile,
  nick.shortcut.other.INodeXml,
  nick.shortcut.element.DLLExpertBase,
  {$IFDEF VER220}
  SysUtils,
  Classes,
  Windows;
  {$ELSE}
  System.SysUtils,
  System.Classes,
  Winapi.Windows;
  {$ENDIF}

type
  TCnWizards = class(TDLLExpertBaseElement)
  private
    procedure PopulatePopupMenuShortcuts();
    procedure PopulateDynamicContextMenuShortcuts;
    procedure MakeShortCuts(const ASourceFileName : string;
                            const ADefaultFileName : string;
                            const ACaptionNodeName : string;
                            const AShortCutNodeName : string;
                            const ADetail : string;
                            const AMenuPath : string);
  protected
    function IsVersionAllowed(const AVSFixedFileInfo : TVSFixedFileInfo) : Boolean; override;
    procedure PopulateShortCuts(); override;
    function GetName() : string; override;
    function GetDescription() : string; override;
  public
    function IsUseable() : Boolean; override;
  end;

function TCnWizards.GetDescription: string;
begin
  Result := 'CnPack IDE Wizards (CnWizards) is a free plug-in tool set for ' +
            'Delphi/C++ Builder/CodeGear RAD Studio to improve development ' +
            'efficiency.' + System.sLineBreak + System.sLineBreak +
            'http://www.cnpack.org';
end;

function TCnWizards.GetName: string;
begin
  Result := 'CnWizards';
end;

function TCnWizards.IsUseable: Boolean;
var
  LToolsApiRepository: IToolsApiRepository;
begin
  LToolsApiRepository := RepositoryFactory().ToolsApiRepository();

  Result := CheckForExpertDLL('CnWizards_D' + LToolsApiRepository.GetIDEName()) or
            CheckForExpertDLL('CnWizards_D' + IntToStr(LToolsApiRepository.GetPackageVersion()));
end;

procedure TCnWizards.PopulateDynamicContextMenuShortcuts;
var
  LSystemRepository: ISystemRepository;
  LToolsApiRepository: IToolsApiRepository;
  LDllName: string;
  LDllHomeDirectory: string;
  LDataPath: string;
  LUserPath: string;
  LRegistryRepository: IRegistryRepository;
  APath: string;
begin
  LSystemRepository := RepositoryFactory.SystemRepository;
  LToolsApiRepository := RepositoryFactory.ToolsApiRepository;

  LDllName := 'CnWizards_D' + LToolsApiRepository.GetIDEName + '.dll';
  LDllHomeDirectory := LSystemRepository.GetModulePath(LDllName);

  if (LDllHomeDirectory = '') then
  begin
    LDllName := 'CnWizards_D' + IntToStr(LToolsApiRepository.GetPackageVersion) + '.dll';
    LDllHomeDirectory := LSystemRepository.GetModulePath(LDllName);
  end;

  if (LDllHomeDirectory = '') then
    Exit;

  LDataPath := IncludeTrailingPathDelimiter(ExtractFilePath(LDllHomeDirectory)) + 'Data\';
  LUserPath := IncludeTrailingPathDelimiter(ExtractFilePath(LDllHomeDirectory)) + 'User\';

  LRegistryRepository := RepositoryFactory.RegistryRepository;
  try
    if not LRegistryRepository.OpenKeyReadOnly('\Software\CnPack\CnWizards\Option') then
      Exit;

    if LRegistryRepository.ValueExists('UseCustomUserDir') and (LRegistryRepository.ReadString('UseCustomUserDir') = '1') and LRegistryRepository.ValueExists('CustomUserDir') then
    begin
      LUserPath := IncludeTrailingPathDelimiter(LRegistryRepository.ReadString('CustomUserDir'));
      if not LSystemRepository.DirectoryExists(LUserPath) then
        if LSystemRepository.GetAppDataDirectory(APath) then
          LUserPath := APath + 'CnWizards\';
    end;
  finally
    LRegistryRepository.CloseKey;
  end;

  MakeShortCuts(LUserPath + 'CodeWrap.xml', LDataPath + 'CodeWrap.xml', 'Caption', 'ShortCut', 'Surround With:', 'Surround With');
  MakeShortCuts(LUserPath + 'GroupReplace.xml', LDataPath + 'GroupReplace.xml', 'Caption', 'ShortCut', 'Group Replace:', 'Group Replace');
  MakeShortCuts(LUserPath + 'WebSearch.xml', LDataPath + 'WebSearch_ENU.xml', 'Caption', 'ShortCut', 'Web Search:', 'Web Search');
end;

procedure TCnWizards.MakeShortCuts(const ASourceFileName : string;
                                   const ADefaultFileName : string;
                                   const ACaptionNodeName : string;
                                   const AShortCutNodeName : string;
                                   const ADetail : string;
                                   const AMenuPath : string);
var
  LCaptionNode: INodeXml;
  LChildNode: INodeXml;
  LInteger: Integer;
  LSystemRepository: ISystemRepository;
  LXmlFileRepository: IXmlFileRepository;
  LNodeXml : INodeXml;
  lp: Integer;
  LShortCut: TShortCut;
  LShortCutNode: INodeXml;
begin
  LSystemRepository := RepositoryFactory.SystemRepository;
  LXmlFileRepository := RepositoryFactory().XmlFileRepository();

  if (LSystemRepository.FileExists(ASourceFileName)) then
    LXmlFileRepository.OpenFile(ASourceFileName)
  else if (LSystemRepository.FileExists(ADefaultFileName)) then
    LXmlFileRepository.OpenFile(ADefaultFileName)
  else
    Exit;

  try
    LXmlFileRepository.Active(True);
  except
    // If any errors are raised while parsing the XML, then abort this process.
    Exit;
  end;

  try
    LNodeXml := LXmlFileRepository.GetRootNode.ChildNode(0);

    for lp := 0 to LNodeXml.ChildNodesCount - 1 do
    begin
      LChildNode := LNodeXml.ChildNode(lp);

      LCaptionNode := LChildNode.GetNode(ACaptionNodeName);
      if (not Assigned(LCaptionNode)) then
        Continue;

      LShortCutNode := LChildNode.GetNode(AShortCutNodeName);
      if (not Assigned(LShortCutNode)) then
        Continue;

      if (TryStrToInt(LShortCutNode.NodeValue, LInteger)) then
        LShortCut := LInteger
      else
        LShortCut := SystemRepository().TextToShortCut(LShortCutNode.NodeValue);

      nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                        .WithDetail(ADetail + LCaptionNode.NodeValue)
                                        .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> ' + AMenuPath + ' -> ' + LCaptionNode.NodeValue)
                                        .WithShortCut(LShortCut)
                                        .Build();
    end;
  finally
    LXmlFileRepository.Active(False);
  end;
end;

function TCnWizards.IsVersionAllowed(const AVSFixedFileInfo: TVSFixedFileInfo): Boolean;
begin
  Result := True;
end;

procedure TCnWizards.PopulatePopupMenuShortcuts;
begin
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Toggle Comment')
                                    .WithDescription('Toggle Comment Selected Code Block' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: Editor RMC -> CnPack Editor Menu -> Comment -> Toggle Comment')
                                    .WithShortCut(SystemRepository().ShortCut({/}VK_OEM_2, [ssCtrl]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Indent block')
                                    .WithDescription('Moves the cursor to the right one tab position / Indents the current selected block by the amount specified in the block indent setting' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: Editor RMC -> CnPack Editor Menu -> Format -> Indent')
                                    .WithShortCut(SystemRepository().ShortCut(VK_TAB, []))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Unindent block')
                                    .WithDescription('Moves the cursor to the left one tab position / Outdents the current selected block by the amount specified in the block indent setting' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: Editor RMC -> CnPack Editor Menu -> Format -> Unindent')
                                    .WithShortCut(SystemRepository().ShortCut(VK_TAB, [ssShift]))
                                    .Build();


  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Copy word under Cursor / selected block')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Edit -> Copy')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('C'), [ssCtrl]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Cut selection to clipboard')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Edit -> Cut')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('C'), [ssCtrl]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Duplicate line')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Edit -> Duplicate')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('D'), [ssCtrl, ssAlt]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Deletes selected block or the character to the right of the cursor')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Edit -> Delete')
                                    .WithShortCut(SystemRepository().ShortCut(VK_DELETE, []))
                                    .Build();


  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Move (line) Up')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Others -> Move Up')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('U'), [ssShift, ssCtrl, ssAlt]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Move (line) Down')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Others -> Move Down')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('D'), [ssShift, ssCtrl, ssAlt]))
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Delete lines')
                                    .WithDescription('Activate: Editor RMC -> CnPack Editor Menu -> Others -> Delete Lines')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('D'), [ssShift, ssCtrl]))
                                    .Build();

  PopulateDynamicContextMenuShortcuts();
end;

procedure TCnWizards.PopulateShortCuts;
var
  LShortCutDecoder : TRegistryDecoder<TShortCut>;
  LEnabledDecoder : TRegistryDecoder<Boolean>;
begin
  LEnabledDecoder := function(const ARegistryRepository : IRegistryRepository; const ASectionKey : string) : Boolean
                     begin
                       Result := Boolean(StrToIntDef(ARegistryRepository.ReadString(ASectionKey), Integer(False)));
                     end;

  LShortCutDecoder := function(const ARegistryRepository : IRegistryRepository; const ASectionKey : string) : TShortCut
                      begin
                        Result := ARegistryRepository.ReadInteger(ASectionKey);
                      end;

  (*
  // Anything below BDS2010
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Use Unit...')
                                    .WithDescription('Show Units to Use' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Use Unit...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtUseUnits')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtUseUnits')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  // Not BDS - Anything below Delphi 8 for .Net
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Run Separately From IDE')
                                    .WithDescription('Run Separately From IDE, without Debugging' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Run Separately From IDE')
                                    .WithShortCut(SystemRepository().ShortCut(VK_F9, [ssShift]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtRunSeparately')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtRunSeparately')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  // Anything below Delphi 2005
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Toggle Comment')
                                    .WithDescription('Toggle Comment Selected Code Block' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Toggle Comment')
                                    .WithShortCut(SystemRepository().ShortCut({/}VK_OEM_2, [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeToggleComment')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeToggleComment')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  // Delphi 5 only...
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Open High Version Forms...')
                                    .WithDescription('Open Forms and Units Created by High Version IDEs.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Open High Version Forms...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnDfm6To5Wizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnDfm6To5Wizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();
  *)
  // ===========================================================================
  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Left Edges')
                                    .WithDescription('Align Left Edges, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Left Edges')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignLeft')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignLeft')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Right Edges')
                                    .WithDescription('Align Right Edges, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Right Edges')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignRight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignRight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Top Edges')
                                    .WithDescription('Align Top Edges, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Top Edges')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignTop')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignTop')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Bottom Edges')
                                    .WithDescription('Align Bottom Edges, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Bottom Edges')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignBottom')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignBottom')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Horizontal Centers')
                                    .WithDescription('Align Horizontal Centers, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Horizontal Centers')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignHCenter')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignHCenter')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align Vertical Centers')
                                    .WithDescription('Align Vertical Centers, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Align Vertical Centers')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignVCenter')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignVCenter')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Space Equally Horizontally')
                                    .WithDescription('Space Equally Horizontally, Enabled when Selected >= 3' + System.sLineBreak + System.sLineBreak +
                                                                            'Activate: CnPack -> Form Design Wizard -> Space Equally Horizontally')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceEquH')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceEquH')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Space Equally Horizontally by...')
                                    .WithDescription('Space Equally Horizontally by a Given Value, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Space Equally Horizontally by...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceEquHX')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceEquHX')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Increase Horizontal Space')
                                    .WithDescription('Increase Horizontal Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Increase Horizontal Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceIncH')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceIncH')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Decrease Horizontal Space')
                                    .WithDescription('Decrease Horizontal Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Decrease Horizontal Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceDecH')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceDecH')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Remove Horizontal Space')
                                    .WithDescription('Remove Horizontal Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Remove Horizontal Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceRemoveH')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceRemoveH')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Space Equally Vertically')
                                    .WithDescription('Space Equally Vertically, Enabled when Selected >= 3' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Space Equally Vertically')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceEquV')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceEquV')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Space Equally Vertically by...')
                                    .WithDescription('Space Equally Vertically by a Given Value, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Space Equally Vertically by...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceEquVY')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceEquVY')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Increase Vertical Space')
                                    .WithDescription('Increase Vertical Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Increase Vertical Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceIncV')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceIncV')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Decrease Vertical Space')
                                    .WithDescription('Decrease Vertical Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Decrease Vertical Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceDecV')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceDecV')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Remove Vertical Space')
                                    .WithDescription('Remove Vertical Space, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Remove Vertical Space')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSpaceRemoveV')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSpaceRemoveV')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Increase Width')
                                    .WithDescription('Increase Width' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Increase Width')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIncWidth')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIncWidth')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Decrease Width')
                                    .WithDescription('Decrease Width' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Decrease Width')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnDecWidth')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnDecWidth')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Increase Height')
                                    .WithDescription('Increase Height' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Increase Height')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIncHeight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIncHeight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Decrease Height')
                                    .WithDescription('Decrease Height' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Decrease Height')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnDecHeight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnDecHeight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Shrink Width to Smallest')
                                    .WithDescription('Shrink Width to Smallest, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Shrink Width to Smallest')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeMinWidth')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeMinWidth')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Grow Width to Largest')
                                    .WithDescription('Grow Width to Largest, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Grow Width to Largest')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeMaxWidth')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeMaxWidth')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Make Same Width')
                                    .WithDescription('Make same width to first selected control, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Make Same Width')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeSameWidth')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeSameWidth')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Shrink Height to Smallest')
                                    .WithDescription('Shrink Height to Smallest, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Shrink Height to Smallest')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeMinHeight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeMinHeight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Grow Height to Largest')
                                    .WithDescription('Grow Height to Largest, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Grow Height to Largest')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeMaxHeight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeMaxHeight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Make Same Height')
                                    .WithDescription('Make same height to first selected control, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Make Same Height')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeSameHeight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeSameHeight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Make Same Size')
                                    .WithDescription('Make same size to first selected control, Enabled when Selected >= 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> Make Same Size')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMakeSameSize')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMakeSameSize')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Center Horizontally')
                                    .WithDescription('Center horizontally in parent' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Center Horizontally')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnParentHCenter')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnParentHCenter')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Center Vertically')
                                    .WithDescription('Center vertically in parent' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Center Vertically')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnParentVCenter')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnParentVCenter')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Bring to Front')
                                    .WithDescription('Bring control to front' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Bring to Front')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnBringToFront')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnBringToFront')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Send to Back')
                                    .WithDescription('Send control to back' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Send to Back')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSendToBack')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSendToBack')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Snap to Grid')
                                    .WithDescription('Snap to grid when control remove or resize' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Snap to Grid')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSnapToGrid')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSnapToGrid')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Designer Guideline')
                                    .WithDescription('Toggle Designer Guideline' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Designer Guideline')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnUseGuidelines')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnUseGuidelines')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Align to Grid')
                                    .WithDescription('Align to grid' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Align to Grid')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAlignToGrid')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignToGrid')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Size to Grid')
                                    .WithDescription('Size to grid' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Size to Grid')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSizeToGrid')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSizeToGrid')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Lock Controls')
                                    .WithDescription('Lock Controls' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Lock Controls')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnLockControls')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnLockControls')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Select Form')
                                    .WithDescription('Select Current Form in Current Designer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Select Form')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSelectRoot')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSelectRoot')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Copy Component''s Name')
                                    .WithDescription('Copy Selected Component''s Name to Clipboard' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Copy Component''s Name')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('N'), [ssCtrl, ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnCopyCompName')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnCopyCompName')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Hide Non-visual')
                                    .WithDescription('Hide / Display the Non-visual Component' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Hide Non-visual')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnHideComponent')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnHideComponent')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Arrange Non-visual...')
                                    .WithDescription('Arrange the Non-visual Components' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Arrange Non-visual...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnNonArrange')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnNonArrange')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Locate Components...')
                                    .WithDescription('Search and Locate Components in Designer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Locate Components...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnListComp')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnListComp')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Convert to Code...')
                                    .WithDescription('Convert Selected Components to Creating Code' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Convert to Code...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnCompToCode')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnCompToCode')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Rename Component')
                                    .WithDescription('Rename Component' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Rename Component')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnCompRename')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnCompRename')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Float Toolbar Options...')
                                    .WithDescription('Float Toolbar Options' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Form Design Wizard -> More... -> Float Toolbar Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnShowFlatForm')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnShowFlatForm')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAlignSizeWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Configurate the Code Editor Wizard' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorWizardConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizardConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Open File...')
                                    .WithDescription('Search and Open File in Search Path.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Open File...')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('O'), [ssCtrl, ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorOpenFile')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorOpenFile')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Eval Swap')
                                    .WithDescription('Swap the Contents of the Evaluation Sign in Both Sides' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Eval Swap')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeSwap')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeSwap')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Editor FullScreen Switch')
                                    .WithDescription('Switch Code Editor in FullScreen and Normal Mode' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Editor FullScreen Switch')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorZoomFullScreen')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorZoomFullScreen')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Convert to String')
                                    .WithDescription('Convert Code Block Selected to String' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Convert to String')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeToString')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeToString')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Delete Blank Lines...')
                                    .WithDescription('Delete Blank Lines' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Delete Blank Lines...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeDelBlank')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeDelBlank')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Comment Code')
                                    .WithDescription('Comment Selected Code Block with //' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Comment Code')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeComment')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeComment')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Uncomment Code')
                                    .WithDescription('Uncomment Selected Code Block Commented by //' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Uncomment Code')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeUnComment')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeUnComment')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Indent')
                                    .WithDescription('Indent Code Block' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Indent')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeIndent')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeIndent')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Unindent')
                                    .WithDescription('Unindent Code Block' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Unindent')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCodeUnIndent')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCodeUnIndent')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('ASCII Chart')
                                    .WithDescription('Display ASCII Chart' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> ASCII Chart')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnAsciiChart')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnAsciiChart')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Insert Color')
                                    .WithDescription('Insert Color' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Insert Color')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorInsertColor')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorInsertColor')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Insert Date Time')
                                    .WithDescription('Insert Date Time' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Insert Date Time')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorInsertTime')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorInsertTime')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Collector')
                                    .WithDescription('Collector' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Collector')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorCollector')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorCollector')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Sort Selected Lines')
                                    .WithDescription('Sort Selected Lines' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Sort Selected Lines')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorSortLines')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorSortLines')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Toggle Uses/Include')
                                    .WithDescription('Jump between Current Place and Uses/Include Part' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Toggle Uses/Include')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('U'), [ssCtrl, ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorToggleUses')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorToggleUses')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Toggle Var Field')
                                    .WithDescription('Jump between Current Place and Var Field' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Toggle Var Field')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('V'), [ssShift, ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorToggleVar')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorToggleVar')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Previous Message Line')
                                    .WithDescription('In Editor, Jump to Previous Line Marked by Selected Item in Message View' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Previous Message Line')
                                    .WithShortCut(SystemRepository().ShortCut({,}VK_OEM_COMMA, [ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorPrevMessage')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorPrevMessage')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Next Message Line')
                                    .WithDescription('In Editor, Jump to Next Line Marked by Selected Item in Message View' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Next Message Line')
                                    .WithShortCut(SystemRepository().ShortCut({.}VK_OEM_PERIOD, [ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorNextMessage')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorNextMessage')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Jump to Intf.')
                                    .WithDescription('Jump to Interface' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Jump to Intf.')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorJumpIntf')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorJumpIntf')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Jump to Impl.')
                                    .WithDescription('Jump to Implementation' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Jump to Impl.')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorJumpImpl')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorJumpImpl')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Jump to Matched Keyword')
                                    .WithDescription('Jump to Matched Keyword under Cursor' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Jump to Matched Keyword')
                                    .WithShortCut(SystemRepository().ShortCut({,}VK_OEM_COMMA, [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorJumpMatchedKeyword')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorJumpMatchedKeyword')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Jump to Previous Identifier')
                                    .WithDescription('Jump to Previous Identifier under Cursor' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Jump to Previous Identifier')
                                    .WithShortCut(SystemRepository().ShortCut(VK_Up, [ssCtrl, ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorJumpPrevIdent')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorJumpPrevIdent')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Jump to Next Identifier')
                                    .WithDescription('Jump to Next Identifier under Cursor' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Jump to Next Identifier')
                                    .WithShortCut(SystemRepository().ShortCut(VK_Down, [ssCtrl, ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorJumpNextIdent')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorJumpNextIdent')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Zoom Larger Font')
                                    .WithDescription('Zoom Larger Editor Font' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Zoom Larger Font')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorFontInc')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorFontInc')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Zoom Smaller Font')
                                    .WithDescription('Zoom Smaller Editor Font' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Code Editor Wizard -> Zoom Smaller Font')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorFontDec')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorFontDec')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('MessageBox...')
                                    .WithDescription('Visual Designer for MessageBox Function' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> MessageBox...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMessageBoxWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMessageBoxWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Component Selector...')
                                    .WithDescription('Selecting Components with Multi-mode.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Component Selector...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnComponentSelector')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnComponentSelector')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Components Selected')
                                    .WithDescription('Auto Set Tab Orders.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> Components Selected')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderSetCurrControl')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderSetCurrControl')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('All Components of Current Form')
                                    .WithDescription('Auto Set Tab Orders in the Form.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> All Components of Current Form')
                                    .WithShortCut(SystemRepository().ShortCut({=}VK_OEM_PLUS, [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderSetCurrForm')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderSetCurrForm')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('All Opened Forms')
                                    .WithDescription('Auto Set Tab Orders in All Opened Forms.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> All Opened Forms')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderSetOpenedForm')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderSetOpenedForm')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('All Forms in Current Project')
                                    .WithDescription('Auto Set Tab Orders in Current Project.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> All Forms in Current Project')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderSetProject')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderSetProject')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('All Forms in Current ProjectGroup')
                                    .WithDescription('Auto Set Tab Orders in Current ProjectGroup.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> All Forms in Current ProjectGroup')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderSetProjectGroup')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderSetProjectGroup')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Auto Update Tab Orders')
                                    .WithDescription('Auto Update Tab Orders after Components Moved.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> Auto Update Tab Orders')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderAutoReset')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderAutoReset')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Display Tab Orders')
                                    .WithDescription('Display Tab Orders in Designing Mode.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> Display Tab Orders')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderDispTabOrder')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderDispTabOrder')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Display Options Dialog of Tab Order Wizard' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Tab Orders -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnTabOrderConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnTabOrderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('BookMark Browser...')
                                    .WithDescription('Browsing BookMarks of All Opening Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> BookMark Browser...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnBookmarkWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnBookmarkWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Source Templates Options' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSrcTemplateConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplateConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Pascal Unit Header')
                                    .WithDescription('Pascal Unit Header' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Pascal Unit Header')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem0')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem0')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('C/C++ Unit Header')
                                    .WithDescription('C/C++ Unit Header' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> C/C++ Unit Header')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem1')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem1')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Pascal Procedure Header')
                                    .WithDescription('Comment for Pascal procedure' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Pascal Procedure Header')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem2')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem2')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Comment Block')
                                    .WithDescription('Comment block' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Comment Block')
                                    .WithShortCut(SystemRepository().ShortCut({,}VK_OEM_COMMA, [ssShift, ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem3')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem3')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Comment Block 2')
                                    .WithDescription('Comment block 2' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Comment Block 2')
                                    .WithShortCut(SystemRepository().ShortCut({.}VK_OEM_PERIOD, [ssShift, ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem4')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem4')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Pascal Class Definition')
                                    .WithDescription('New Pascal Class Definition' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Pascal Class Definition')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem5')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem5')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Unit initialization')
                                    .WithDescription('initialization' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Templates -> Unit initialization')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnEditorItem6')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnEditorItem6')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSrcTemplate')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Set MSDN wizard Options' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> MSDN Help Wizard -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMsdnWizRunConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizRunConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('MSDN Help...')
                                    .WithDescription('Open MSDN help' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> MSDN Help Wizard -> MSDN Help...')
                                    .WithShortCut(SystemRepository().ShortCut(VK_F1, [ssAlt]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMsdnWizRunMsdn')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizRunMsdn')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('MSDN Search...')
                                    .WithDescription('Open MSDN Search' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> MSDN Help Wizard -> MSDN Search...')
                                    .WithShortCut(SystemRepository().ShortCut(VK_F1, [ssShift]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnMsdnWizRunSearch')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizRunSearch')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnMsdnWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Copy as HTML Format')
                                    .WithDescription('Convert the Current Selection to HTML Format and Copy to Clipboard' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Copy as HTML Format')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardCopySelected')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardCopySelected')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Export Unit...')
                                    .WithDescription('Export Current Unit to a HTML or RTF File' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Export Unit...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardExportUnit')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardExportUnit')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Export All Opened...')
                                    .WithDescription('Exports All Opened Units to HTML or RTF Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Export All Opened...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardExportOpened')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardExportOpened')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Export Current Project...')
                                    .WithDescription('Export Current Project to HTML or RTF Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Export Current Project...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardExportDPR')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardExportDPR')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Export Project Group...')
                                    .WithDescription('Export Current ProjectGroup to HTML or RTF Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Export Project Group...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardExportBPG')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardExportBPG')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Convert Output Options' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Export to HTML/RTF -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPas2HtmlWizardConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizardConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPas2HtmlWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Replace in Files...')
                                    .WithDescription('Replace in Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Replace in Files...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnReplaceWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnReplaceWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Source Compare...')
                                    .WithDescription('Compare and Merge Source Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Compare...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnSourceDiffWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnSourceDiffWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Source Statistics...')
                                    .WithDescription('Source Statistics' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Source Statistics...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnStatWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnStatWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Prefix Wizard...')
                                    .WithDescription('Rename Prefix of Components' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Prefix Wizard...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnPrefixWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnPrefixWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Property Corrector...')
                                    .WithDescription('Correct Properties According to Some Customized Rules' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Property Corrector...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnCorPropWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnCorPropWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Browse Current File''s Dir...')
                                    .WithDescription('Open Current File''s Directory in Windows Explorer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Browse Current File''s Dir...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtExploreUnit')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtExploreUnit')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Browse Project Dir...')
                                    .WithDescription('Open Project Directory in Windows Explorer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Browse Project Dir...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtExploreProject')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtExploreProject')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Browse Output Dir...')
                                    .WithDescription('Open Output Directory in Windows Explorer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Browse Output Dir...')
                                    .WithShortCut(SystemRepository().ShortCut({\}VK_OEM_5, [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtExploreExe')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtExploreExe')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('List Units...')
                                    .WithDescription('Display Units List in Project Group' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> List Units...')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('U'), [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtViewUnits')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtViewUnits')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('List Forms...')
                                    .WithDescription('Display Forms List in Project Group' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> List Forms...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtViewForms')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtViewForms')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('List Used...')
                                    .WithDescription('Show Units that Used by Current Unit' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> List Used...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtListUsed')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtListUsed')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Project Backup...')
                                    .WithDescription('Compress and Backup Project Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Project Backup...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtBackup')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtBackup')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Clean Temporary Files...')
                                    .WithDescription('Clean Temporary Files in Project' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Clean Temporary Files...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtDelTemp')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtDelTemp')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Project Dir Builder...')
                                    .WithDescription('Open Project Dir Builder' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Project Enhancements -> Project Dir Builder...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtDirBuilder')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtDirBuilder')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjectExtWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Comments Cropper...')
                                    .WithDescription('Crop Comments in Source Code' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Comments Cropper...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnCommentCropperWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnCommentCropperWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('INI Reader and Writer')
                                    .WithDescription('Generate a Read and Write Unit from a INI file.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Repository List -> INI Reader and Writer')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnRepositoryMenu0CnIniFilerWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnRepositoryMenu0CnIniFilerWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnRepositoryMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('CnMemProf Project')
                                    .WithDescription('Generate A Project with CnMemProf to Report Memory Usage.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Repository List -> CnMemProf Project')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnRepositoryMenu1CnMemProfWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnRepositoryMenu1CnMemProfWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnRepositoryMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Explorer...')
                                    .WithDescription('Embedded Windows Explorer. Its Functions include Filtering, Favorites and Cleaning Temporary Files.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Explorer...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnExplorerWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnExplorerWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Create a Snapshot...')
                                    .WithDescription('Create a Snapshot of Opened Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Historical Files Snapshot -> Create a Snapshot...')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('W'), [ssShift, ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtFilesSnapshotAdd')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtFilesSnapshotAdd')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnFilesSnapshotWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Manage Snapshot List...')
                                    .WithDescription('Manage Snapshot List' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Historical Files Snapshot -> Manage Snapshot List...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtFilesSnapshotManage')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtFilesSnapshotManage')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnFilesSnapshotWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Open Historical Files...')
                                    .WithDescription('Open Historical Files' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Historical Files Snapshot -> Open Historical Files...')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('O'), [ssShift, ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProjExtFileReopen')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProjExtFileReopen')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnFilesSnapshotWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Procedure List...')
                                    .WithDescription('List All Procedures and Functions in Current Source File' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Procedure List...')
                                    .WithShortCut(SystemRepository().ShortCut(Ord('D'), [ssCtrl]))
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnProcListWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnProcListWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Uses Cleaner...')
                                    .WithDescription('Clean Unused Units Reference' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Uses Cleaner...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnUsesCleaner')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnUsesCleaner')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Form Designer Enhancements')
                                    .WithDescription('Form Designer Enhancements' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> Form Designer Enhancements')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu0CnFormEnhanceWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu0CnFormEnhanceWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Source Highlight Enhancements')
                                    .WithDescription('Bracket Match & Structure Highlight' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> Source Highlight Enhancements')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu1CnSourceHighlight')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu1CnSourceHighlight')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Editor Enhancements')
                                    .WithDescription('Editor Enhancements' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> Editor Enhancements')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu2CnSrcEditorEnhance')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu2CnSrcEditorEnhance')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('IDE Main Form Enhancements')
                                    .WithDescription('Component Palette & Main Form Enhancements' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> IDE Main Form Enhancements')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu3CnPaletteEnhanceWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu3CnPaletteEnhanceWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Code Input Helper')
                                    .WithDescription('Auto Drop Down Window like Code-Insight' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> Code Input Helper')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu4CnInputHelper')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu4CnInputHelper')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Version Enhancements')
                                    .WithDescription('Version Enhancements Wizard' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> Version Enhancements')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu5CnVerEnhanceWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu5CnVerEnhanceWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('FeedReader Wizard')
                                    .WithDescription('Display Feed Content in Status Bar' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Enhancements Settings -> FeedReader Wizard')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeEnhanceMenu6CnFeedReaderWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenu6CnFeedReaderWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeEnhanceMenuWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('IDE Config Backup/Restore...')
                                    .WithDescription('Open Forms and Units Created by High Version IDEs.' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> IDE Config Backup/Restore...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnIdeBRWizard')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnIdeBRWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Script Window...')
                                    .WithDescription('Show the Script Window' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Script Wizard -> Script Window...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnScriptForm')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptForm')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Script Library...')
                                    .WithDescription('Script Libary Window' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Script Wizard -> Script Library...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnScriptWizardConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptWizardConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Browse Demo...')
                                    .WithDescription('Open Script Demo Directory in Windows Explorer' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Script Wizard -> Browse Demo...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnScriptBrowseDemo')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptBrowseDemo')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnScriptWizard')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Options...')
                                    .WithDescription('Options of CnPack IDE Wizards' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Options...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizConfig')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizConfig')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('???? - Chinese (Traditional, Taiwan)')
                                    .WithDescription('????' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Languages -> ???? - Chinese (Traditional, Taiwan)')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('Language0CHT')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('Language0CHT')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizMultiLang')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('German - German (Germany)')
                                    .WithDescription('German' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Languages -> German - German (Germany)')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('Language1DEU')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('Language1DEU')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizMultiLang')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('English - English (United States)')
                                    .WithDescription('English' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Languages -> English - English (United States)')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('Language2ENU')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('Language2ENU')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizMultiLang')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Russian - Russian (Russia)')
                                    .WithDescription('Russian' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Languages -> Russian - Russian (Russia)')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('Language3RUS')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('Language3RUS')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizMultiLang')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('???? - Chinese (Simplified, PRC)')
                                    .WithDescription('????' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> Languages -> ???? - Chinese (Simplified, PRC)')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('Language4CHS')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('Language4CHS')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizMultiLang')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Help Topics...')
                                    .WithDescription('CnPack IDE Wizards Help' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Help Topics...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutHelp')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutHelp')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Update History...')
                                    .WithDescription('CnPack IDE Wizards Update History' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Update History...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutHistory')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutHistory')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Tip of Day...')
                                    .WithDescription('Display the Tip of Day' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Tip of Day...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutTipOfDay')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutTipOfDay')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Bug Report or Suggestions...')
                                    .WithDescription('Open the Wizards to Report Error or Send Suggestion' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Bug Report or Suggestions...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutBugReport')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutBugReport')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Check Update...')
                                    .WithDescription('Check the Latest Version of CnPack IDE Wizards' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Check Update...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutUpgrade')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutUpgrade')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Config Import/Export...')
                                    .WithDescription('Load/Save the Config Info of CnPack IDE Wizards' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Config Import/Export...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutConfigIO')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutConfigIO')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('CnPack WebSite')
                                    .WithDescription('Access the CnPack WebSite' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> CnPack WebSite')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutUrl')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutUrl')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('CnPack Forum')
                                    .WithDescription('Access CnPack Forum' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> CnPack Forum')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutBbs')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutBbs')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('Email')
                                    .WithDescription('Write Mail to CnPack' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> Email')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutMail')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutMail')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();

  nick.shortcut.builder.ShortCutItem.NewShortCutItemBuilder(Self)
                                    .WithDetail('About...')
                                    .WithDescription('About CnPack IDE Wizards' + System.sLineBreak + System.sLineBreak +
                                                     'Activate: CnPack -> About... -> About...')
                                    .WithShortCut(scNone)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\ShortCuts')
                                    .WithKey('CnWizAboutAbout')
                                    .WithDecoder(LShortCutDecoder)
                                    .WithActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAboutAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .WithParentActiveState(True)
                                    .IsRegistry()
                                    .WithPath('\Software\CnPack\CnWizards\Active')
                                    .WithKey('CnWizAbout')
                                    .WithDecoder(LEnabledDecoder)
                                    .Build();


  PopulatePopupMenuShortcuts();
end;

initialization
  nick.shortcut.repository.ShortCut.GetShortCutRepository().Add(TCnWizards);

end.
