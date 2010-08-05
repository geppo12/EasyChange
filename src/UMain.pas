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
    procedure sgPropertySelectCell(Sender: TObject; ACol, ARow: Integer;
      var CanSelect: Boolean);
    procedure sgPropertySetEditText(Sender: TObject; ACol, ARow: Integer; const
        Value: string);
  private
    { Private declarations }
    FSelectFile: Boolean;
    FLastDir: string;   // #MEMO temporaneo
    FFileName: string;
    FEditingRow: Integer;
    FDataFile: TECDataFile;
    FOldSgWndProc: TWndMethod;

    { general private method }
    procedure showValues;
    procedure clearGridSel;
    procedure doLoad;
    procedure doDrop(var AMsg: TWMDropFiles);
    procedure closeEditing(AData: string);
    procedure setControlPos(ARect: TRect; ACtrl: TControl);
    procedure setCtrlVisible(ACtrlKind: TECValueKind);
    procedure setDocs(ADocs: string);
    procedure createBackup(AFileName: string);
    procedure sgWndProc(var AMsg: TMessage);
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
  kBooleanMargin = 3;
  kHeightMargin = 3;
  kWidthMargin = 3;
  kTrueStr = 'True';
  kFalseStr = 'False';

procedure MsgBox(const AMessage: string);
begin
  Application.MessageBox(PAnsiChar(AMessage),PAnsiChar(Application.Title),MB_OK);
end;

{ TfmMain -------------------------------------------------------------------- }

procedure TfmMain.showValues;
var
  LRowIndex: Integer;
  LValue: TECValue;
  LRow: TStrings;
begin
  sgProperty.RowCount := FDataFile.ValueList.Count;

  for LRowIndex := 0 to FDataFile.ValueList.Count-1 do begin
    LValue := FDataFile.ValueList.Values[LRowIndex];
    LRow := sgProperty.Rows[LRowIndex];
    LRow.Clear;
    { NOTA: 1 e' la colonna di destra }
    LRow.Objects[1] := LValue;
    LRow.Add(LValue.Name);
    LRow.Add(LValue.OptionName);
  end;
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

procedure TfmMain.doLoad;
begin
  FDataFile.LoadFromFile(FFileName);

  if FDataFile.InvalidString > 0  then
    MsgBox(Format('%d Invalid String in header',[FDataFile.InvalidString]))
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
    FFileName := LBuffer;
    eFilename.Text := LBuffer;
    doLoad;
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

{* TfmMain.setControlPos
   imposta la posizione dei controlli ausiliari }
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
begin
  case ACtrlKind of
    { server per disbilitare tutti i controlli quando sono fuori
      da una selezione }
    vkUnknown,
    vkBoolean,
    vkString: begin
        cbMultiple.Visible := False;
        btnPath.Visible := False;
      end;
    vkFile,
    vkPath: begin
        cbMultiple.Visible := False;
        btnPath.Visible := True;
      end;
    vkMultiple: begin
        LRect.Left := -1;
        LRect.Top := -1;
        LRect.Right := -1;
        LRect.Bottom := -1;
        sgProperty.Selection := LRect;
        cbMultiple.Visible := True;
        btnPath.Visible := False;
      end;
  end;
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

procedure TfmMain.sgWndProc(var AMsg: TMessage);
begin
  if AMsg.Msg = WM_DROPFILES then
    doDrop(TWMDropFiles(AMsg))
  else
    FOldSgWndProc(AMsg);
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
            if LValue.OptionName = kTrueStr then
              closeEditing(kFalseStr)
            else if LValue.OptionName = kFalseStr then
              closeEditing(kTrueStr);
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
  FDataFile := TECDataFile.Create;
  { Abilitazione SmartInspect }
{$IFDEF _ENABLE_DEBUG}
  Si.Enabled := True;
  Si.Level := lvDebug;
  Si.DefaultLevel := lvDebug;
{$ELSE}
  Si.Enabled := False;
{$ENDIF}
  SiMain.ClearAll;
  FEditingRow := -1;
  if ParamCount = 0 then begin
    DragAcceptFiles(sgProperty.Handle,true);
    FOldSgWndProc := sgProperty.WindowProc;
    sgProperty.WindowProc := sgWndProc;
  end;
end;

procedure TfmMain.FormDestroy(Sender: TObject);
begin
  FDataFile.Free;
end;

procedure TfmMain.btnSelectClick(Sender: TObject);
begin
  if odLoadFile.Execute then begin
    eFileName.Text := odLoadFile.Filename;
    if FFileName <> eFileName.Text then
      FFileName :=  eFileName.Text;
    doLoad;
  end;
end;

procedure TfmMain.btnExitClick(Sender: TObject);
begin
  Close;
end;

procedure TfmMain.btnOkClick(Sender: TObject);
begin
  createBackup(FFileName);
  FDataFile.ReplaceAll;
  FDataFile.SaveToFile(FFileName);
  if ParamCount = 1 then
    Close;
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
begin
  if (Key = VK_F5) and FileExists(FFilename) then
    doLoad;
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
  Caption := Caption + ' V'+VersionInformation(k3DigitWithBeta,
{$IFDEF _BETA_VERSION}
  True);
{$ELSE}
  False);
 {$ENDIF}

  if ParamCount > 0 then begin
    with sgProperty do
      Height := Height + Top - eFilename.Top;
    sgProperty.Top := eFileName.Top;
    eFileName.Visible := False;
    btnSelect.Visible := False;
    FFileName := ParamStr(1);
    doLoad;
    Caption := Caption + ' - ' + ExtractFilename(ParamStr(1));
  end;
end;

procedure TfmMain.sgPropertySetEditText(Sender: TObject; ACol, ARow: Integer;
    const Value: string);
begin
  if not sgProperty.EditorMode then
    closeEditing(sgProperty.Cols[1].Strings[ARow]);
end;


{ #DEBUG }
end.
