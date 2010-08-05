unit UMain;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, FileCtrl, Grids, ValEdit, UCore;


{ se definito crea non solo un file vecchio come bku ma la storia  come ~1,~2 }
{$DEFINE _HISTORY}

{ se definito viene abilitato il debug su smart inspect senza bisogno dei file sic }
{$DEFINE _ENABLE_DEBUG}

{$DEFINE _BETA_VERSION}
const
  {* tipo di progetto EasyChange }
  kProjectExt = '.ecp';
type

  TfmMain = class(TForm)
    eFileName: TEdit;
    btnSelect: TButton;
    btnOk: TButton;
    odLoadFile: TOpenDialog;
    cbMultiple: TComboBox;
    btnPath: TButton;
    sgProperty: TStringGrid;
    btnExit: TButton;
    mDoc: TMemo;
    cbUseProject: TCheckBox;
    lbFiles: TListBox;
    procedure btnExitClick(Sender: TObject);
    procedure btnOkClick(Sender: TObject);
    procedure btnPathClick(Sender: TObject);
    procedure btnSelectClick(Sender: TObject);
    procedure cbMultipleSelect(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormResize(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure lbFilesClick(Sender: TObject);
    procedure sgPropertySelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure sgPropertySetEditText(Sender: TObject; ACol, ARow: Integer; const
        Value: string);
  private
    { Private declarations }
    FSelectFile: Boolean;
    FLastDir: string;   // #MEMO temporaneo
    FEditingRow: Integer;
    {* Lista dei file da processare }
    FFiles: TStringList;
    FOldWndProc: TWndMethod;

    { general private method }
    procedure siLocalInit;
    procedure clear;
    procedure clearGrid;
    procedure resetControls;
    function getCurrentDataFile: TECDataFile;
    procedure showValues;
    procedure clearGridSel;
    procedure doLoad(AFileName: string);
    procedure doDrop(var AMsg: TWMDropFiles);
    procedure closeEditing(AData: string);
    //1 imposta la posizione dei controlli ausiliari
    procedure setControlPos(ARect: TRect; ACtrl: TControl);
    {* Seleziona i controlli nascosti da visualizzare in base al tipo di valore
       @parm ACtrlKind  tipo del valore da visualizzare }
    procedure setCtrlVisible(ACtrlKind: TECValueKind);
    procedure setDocs(ADocs: string);
    procedure createBackup(AFileName: string);
    procedure newWndProc(var AMsg: TMessage);
  public

    { Public declarations }
  end;

var
  fmMain: TfmMain;

implementation

uses
  SiAuto,
  SmartInspect,
  StrUtils,
  ShellApi,
  UFileVersion;

{$R *.dfm}

const
  // smart inspect related
  kSiConnetion = 'file(append="true", filename="log.sil", maxsize="500MB")';
  kSiDebugLevel = lvDebug;
  kSiDefaultLevel = lvDebug;

  kBooleanMargin = 3;
  kHeightMargin = 3;
  kWidthMargin = 3;
  kTrueStr = 'True';
  kFalseStr = 'False';

procedure MsgBox(const AMessage: string);
begin
  Application.MessageBox(PChar(AMessage),PChar(Application.Title),MB_OK);
end;

{ TfmMain -------------------------------------------------------------------- }
procedure TfmMain.siLocalInit;
var
  LFileNameSic: string;
  LFileNameSil: string;
  LFileDir: string;
  sicDone: Boolean;
begin
  sicDone := False;
  LFileNameSil := ChangeFileExt('c:\' + ExtractFileName(Application.ExeName),'.sil');
  Si.SetVariable('filename',LFileNameSil);

  LFileNameSic := ChangeFileExt(Application.ExeName,'.sic');
  if FileExists(LFileNameSic) then begin
    Si.LoadConfiguration(LFileNameSic);
    sicDone := True;
  end;

  if not sicDone then begin
    Si.Connections := kSiConnetion;
    Si.Level  := kSiDebugLevel;
    Si.DefaultLevel := kSiDefaultLevel;
    Si.Enabled := True;
  end;
{$IFDEF _MICROSEC}
  Si.Resolution := crHigh;
{$ENDIF}
  SiMain.ClearAll;

{$IFNDEF EUREKALOG}
  Application.OnException := SiMain.ExceptionHandler;
{$ENDIF}
end;

procedure TfmMain.clear;
var
  I: Integer;
begin
  clearGrid;
  for I := 0 to lbFiles.Count - 1 do
    lbFiles.Items.Objects[I].Free;

  lbFiles.clear;
end;

procedure TfmMain.clearGrid;
begin
  sgProperty.Cols[0].Clear;
  sgProperty.Cols[1].Clear;
end;

procedure TfmMain.resetControls;
begin
  cbMultiple.Visible := False;
  btnPath.Visible := False;
end;

function TfmMain.getCurrentDataFile: TECDataFile;
begin
  if lbFiles.ItemIndex >= 0 then
    Result := lbFiles.Items.Objects[lbFiles.ItemIndex] as TECDataFile
  else
    raise EECNoDataFile.Create('no data file');
end;


procedure TfmMain.showValues;
var
  LDataFile: TECDataFile;
  LRowIndex: Integer;
  LValue: TECValue;
  LRow: TStrings;
begin
  SiMain.EnterMethod(Self, 'showValues');
  try
    LDataFile := getCurrentDataFile;
    sgProperty.RowCount := LDataFile.ValueList.Count;

    for LRowIndex := 0 to LDataFile.ValueList.Count-1 do begin
      LValue := LDataFile.ValueList.Values[LRowIndex];
      LRow := sgProperty.Rows[LRowIndex];
      LRow.Clear;
      { NOTA: 1 e' la colonna di destra }
      LRow.Objects[1] := LValue;
      LRow.Add(LValue.Name);
      LRow.Add(LValue.OptionName);
    end;
  except
    { su questa eccezione non fa niente }
    on EECNoDataFile do
      SiMain.LogException;
  end;
  SiMain.LeaveMethod(Self, 'showValues');
end;

procedure TfmMain.clearGridSel;
var
  LRect: TGridRect;
begin
  LRect.Left := -1;
  LRect.Top := -1;
  LRect.Right := -1;
  LRect.Bottom := -1;
  sgProperty.Selection := LRect;
  ActiveControl := sgProperty;
end;

procedure TfmMain.doLoad(AFileName: string);
var
  I: Integer;
  LDataFile: TECDataFile;
begin
  clear;
  LDataFile := TECDataFile.Create;
  if (ExtractFileExt(AFileName) = kProjectExt) and cbUseProject.Checked then begin
    FFiles.LoadFromFile(AFileName);
    for I := FFiles.Count - 1 downto 0 do begin
      LDataFile.LoadFromFile(FFiles[I]);
      if LDataFile.Count <> 0 then begin
        lbFiles.AddItem(ExtractFilename(FFiles[I]),LDataFile);
        LDataFile := TECDataFile.Create;
      end else
        FFiles.Delete(I);
    end;
    LDataFile.Free;
    lbFiles.ItemIndex := 0;
    showValues;
  end else begin
    FFiles.Add(AFileName);
    LDataFile.LoadFromFile(ExtractFilename(AFileName));
    lbFiles.AddItem(AFileName,LDataFile);
    lbFiles.ItemIndex := 1;
  end;

  if LDataFile.InvalidString > 0  then
    MsgBox(Format('%d Invalid String in header',[LDataFile.InvalidString]))
  else
    showValues;
end;

procedure TfmMain.doDrop(var AMsg: TWMDropFiles);
var
  LNumFiles: Integer;
  LBuffer : array[0..MAX_PATH] of char;
begin
  LNumFiles := DragQueryFile(AMsg.Drop, $FFFFFFFF, nil, 0) ;
  if LNumFiles = 1 then begin
    DragQueryFile(AMsg.Drop, 0, @LBuffer, sizeof(LBuffer)) ;
    doLoad(LBuffer);
  end;
end;

procedure TfmMain.closeEditing(AData: string);
var
  LValue: TECValue;
begin
  if FEditingRow >= 0 then
    with sgProperty.Cols[1] do begin
      SiMain.LogDebug('Close line');
      LValue := Objects[FEditingRow] as TECValue;
      Strings[FEditingRow] := AData;
      LValue.OptionName := AData;
      clearGridSel;
      FEditingRow := -1;
    end else
      SiMain.LogDebug('No line to close');
end;

procedure TfmMain.setControlPos(ARect: TRect; ACtrl: TControl);
var
  LCellWidth: Integer;
begin
  if ACtrl is TComboBox then begin
    ACtrl.Top := sgProperty.Top+ARect.Top + 4;
    ACtrl.Left := sgProperty.Left+ARect.Left + 2;
    ACtrl.Width := ARect.Right-ARect.Left;
  end else if ACtrl is TButton then begin
    LCellWidth := ARect.Right - ARect.Left;
    btnPath.Top := sgProperty.Top+ARect.Top + 2;
    btnPath.Left := sgProperty.Left+ARect.Left+LCellWidth-btnPath.Width+2;
  end;
end;

procedure TfmMain.setCtrlVisible(ACtrlKind: TECValueKind);
var
  LRect: TGridRect;
  LMultiple: Boolean;
  LPath: Boolean;
begin
  LMultiple := False;
  LPath     := False;
  case ACtrlKind of
    vkString: ;
    vkFile,
    vkPath: LPath := True;
    vkBoolean,
    vkMultiple: begin
        LRect.Left := -1;
        LRect.Top := -1;
        LRect.Right := -1;
        LRect.Bottom := -1;
        LMultiple := True;
      end;
  end;
  btnPath.Visible    := LPath;
  cbMultiple.Visible := LMultiple;
end;

procedure TfmMain.setDocs(ADocs: string);
var
  I: Integer;
  LPos: Integer;
  LString: string;
  LEnd: Boolean;
begin
  LEnd := False;
  repeat
    LPos := Pos('\r',ADocs);
    if LPos > 0 then begin
      LString := LeftStr(ADocs,LPos-1);
      ADocs := RightStr(ADocs,Length(ADocs)-LPos);
    end else begin
      LString := ADocs;
      LEnd := True;
    end;
    mDoc.Lines.Add(LString);
  until LEnd;
end;

procedure TfmMain.createBackup(AFileName: string);
var
  LNewName: string;
{$IFDEF _HISTORY}
  I: Integer;
{$ENDIF}
begin
{$IFDEF _HISTORY}
  I := 1;
  repeat
    LNewName := AFileName+'~'+IntToStr(I);
    Inc(I);
  until not FileExists(LNewName);
{$IFDEF _SAFE_MODE}
  { applicativo sperimentale. se non copio il backup, preferisco che fallisca
    con un assert }
  Assert(CopyFile(PChar(AFileName),PChar(LNewName),False));
{$ELSE}
  CopyFile(PChar(AFileName),PChar(LNewName),False);
{$ENDIF}
{$ELSE}
  { aggiungo solo perche non voglio perdere l'estensione originale }
  LNewName := AFileName+'.bak';
  CopyFile(PChar(AFileName),PChar(LNewName),False);
{$ENDIF}
end;

procedure TfmMain.newWndProc(var AMsg: TMessage);
begin
  if AMsg.Msg = WM_DROPFILES then
    doDrop(TWMDropFiles(AMsg))
  else
    FOldWndProc(AMsg);
end;


procedure TfmMain.sgPropertySelectCell(Sender: TObject; ACol, ARow: Integer;
  var CanSelect: Boolean);
var
  LValue: TECValue;
  LRect: TRect;
  LCellWidth: Integer;
begin
  SiMain.LogDebug('FORM: SelectCell(R:%d,C:%d)',[ARow,ACol]);
  CanSelect := False;
  LValue := nil;

  LValue := sgProperty.Cols[1].Objects[ARow] as TECValue;
  { gestione della documentazione dell'entry.
    NOTA: abilitare valutazione degli operatori stile C }
  { cancella la vecchia documentazione }
  mDoc.Lines.Clear;
  { imposta la nuova documentazione se presente }
  if (LValue <> nil) and (LValue.Docs <> '') then
    setDocs(LValue.Docs);

  { gestione della modifica dell'entry }
  if ACol = 1 then begin
    if LValue <> nil then begin
      FEditingRow := ARow;
      FSelectFile := False;
      LRect := sgProperty.CellRect(ACol,ARow);
      case LValue.Kind of
        vkBoolean: begin
            setControlPos(LRect,cbMultiple);
            cbMultiple.Clear;
            cbMultiple.Items.Add('False');
            cbMultiple.Items.Add('True');
            cbMultiple.Visible := True;

            if LValue.OptionName = kTrueStr then
              cbMultiple.ItemIndex := 1
            else if LValue.OptionName = kFalseStr then
              cbMultiple.ItemIndex := 0;
            CanSelect := False;
          end;

        vkMultiple: begin
            { posiziono il combo box nella posizione opportuna }
            setControlPos(LRect,cbMultiple);
            LValue.ValuesAssignTo(cbMultiple.Items);
            SiMain.LogInteger('FORM: LValue.ActualValueIdx',LValue.ActualValueIdx);
            cbMultiple.ItemIndex := LValue.ActualValueIdx;
            cbMultiple.Visible := True;
          end;

        vkFile: begin
            FSelectFile := True;
            FLastDir := ExtractFilePath(LValue.OptionName);
            setControlPos(LRect,btnPath);
            CanSelect := True;
          end;

        vkPath: begin
            FLastDir := LValue.OptionName;
            setControlPos(LRect,btnPath);
            CanSelect := True;
          end;

        vkString: begin
            CanSelect := True;
          end;
      end;
      setCtrlVisible(LValue.Kind);

    end; { end 'LValue <> nil' }
  end else
    cbMultiple.Visible := False;
end;

procedure TfmMain.FormCreate(Sender: TObject);
begin
  { Abilitazione SmartInspect }
  siLocalInit;
  SiMain.LogMessage('Start EasyChange %s',[VersionInformation(k4DigitPlain)]);
  SiMain.LogSystem;
  FEditingRow := -1;
  FFiles := TStringList.Create;
  if ParamCount = 0 then begin
    DragAcceptFiles(Handle,true);
    FOldWndProc := WindowProc;
    WindowProc := newWndProc;
  end;
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  FFiles.Free;
  SiMain.LogMessage('Close EasyChange');
end;

procedure TfmMain.btnSelectClick(Sender: TObject);
begin
  if odLoadFile.Execute then
    doLoad(odLoadFile.Filename);
end;

procedure TfmMain.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfmMain.btnOkClick(Sender: TObject);
var
  LDataFile: TECDataFile;
begin
  if lbFiles.ItemIndex >= 0 then begin
    if FileExists(FFiles[lbFiles.ItemIndex]) then begin
      createBackup(FFiles[lbFiles.ItemIndex]);
      LDataFile := getCurrentDataFile;
      LDataFile.ReplaceAll;
      LDataFile.SaveToFile(FFiles[lbFiles.ItemIndex]);
      if ParamCount = 1 then
        Close;
    end;
  end;
end;

procedure TfmMain.btnPathClick(Sender: TObject);
var
  LOptions: TSelectDirExtOpts;
  LValidDir: Boolean;
  LDir: string;
begin
  if not FSelectFile then begin
    LDir := FLastDir;
    LOptions := [sdNewFolder];
    LValidDir := SelectDirectory(Application.Title,WideString(''),LDir,
      LOptions, Self);
    if LValidDir then begin
      FLastDir := LDir;
      closeEditing(LDir);
    end;
  end else begin
    odLoadFile.InitialDir := FLastDir;
    if odLoadFile.Execute then
      closeEditing(odLoadFile.FileName);
  end;
end;

procedure TfmMain.cbMultipleSelect(Sender: TObject);
begin
  closeEditing(cbMultiple.Items[cbMultiple.ItemIndex]);
  setCtrlVisible(vkUnknown);
end;

{ per effettuare un refresh con F5 }
procedure TfmMain.FormKeyDown(Sender: TObject; var Key: Word; Shift:
    TShiftState);
var
  LIndex: Integer;
begin
  LIndex := lbFiles.ItemIndex;
  if LIndex >= 0 then begin
    if (Key = VK_F5) and FileExists(FFiles[LIndex]) then
      doLoad(FFiles[LIndex]);
  end;
end;

procedure TfmMain.FormResize(Sender: TObject);
var
  LWidth: Integer;
begin
  LWidth := sgProperty.Width div 2;
  sgProperty.ColWidths[0] := LWidth-kWidthMargin;
  sgProperty.ColWidths[1] := LWidth-kWidthMargin;
  mDoc.Top := sgProperty.Top + sgProperty.Height + kHeightMargin;

end;

procedure TfmMain.FormShow(Sender: TObject);
begin
  clearGridSel;
  Caption := Caption + ' V'+VersionInformation(k4DigitPlain);
{$IFDEF _BETA_VERSION}
  Caption := Caption + ' Beta';
{$ENDIF}

  if ParamCount > 0 then begin
    with sgProperty do
      Height := Height + Top - eFilename.Top;
    sgProperty.Top := eFileName.Top;
    eFileName.Visible := False;
    btnSelect.Visible := False;
    doLoad(ParamStr(1));
  end;
end;

procedure TfmMain.lbFilesClick(Sender: TObject);
begin
  if lbFiles.ItemIndex >= 0 then begin
    resetControls;
    showValues;
  end else
    clearGrid
end;

procedure TfmMain.sgPropertySetEditText(Sender: TObject; ACol, ARow: Integer;
    const Value: string);
begin
  if not sgProperty.EditorMode then
    closeEditing(sgProperty.Cols[1].Strings[ARow]);
end;


{ #DEBUG }
end.
