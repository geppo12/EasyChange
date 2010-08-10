unit UCore;

interface

uses
  SysUtils,
  Classes,
  Contnrs;


{ se definito emette ulteriori informazioni di debug circa la composizione del
  file }
{$DEFINE EXTENDED_DEBUG}

resourcestring
  kInvalidStringStr = 'Stringa ''%s'' invalida';

const
  kStrHeader = '@GM@';
  kStrDocHeader = '@GM-DOC@';
  kFileHeaderEnd = '@GM-END@';
  kStrEnd    = '@GM!';
  kStrMagicVar = '@%';
  kTabConsStr = '~~';
  kEscapeChar = '$';
  kDocSeparator = '::';

type

  { tipi di valori }
  TECValueKind = (
    vkUnknown,
    vkString,
    vkPath,
    vkFile,
    vkBoolean,
    vkMultiple,
    vkRange
  );

  TECStringType = (
    stName,
    stValue,
    stPair
  );

  //* Usato per dividere una stringa ed mantenere la parte utile */
  TECSplittedString = record
    StartStr: string;
    ContentStr: string;
    EndStr: string;
  end;

  EECException = class(Exception)
    public
    constructor Create(const AMsg: string);
  end;

  EECInvalidString = class(EECException)
    public
    constructor Create(const AMsg: string);
  end;

  EECInvalidIndex = class(EECException)
    public
    constructor Create;
  end;

  EECInvalidOperation = class(EECException)
    public
    constructor Create(const AMsg: string);
  end;

  EECNoDataFile = class(EECException)
    public
    constructor Create(const AMsg: string);
  end;

  TECParamBuilder = class
    private
    FStringBuilder: TStringList;
    FEscape: Boolean;
    FQuote: Boolean;
    FPairComplete: Boolean;
    FCompleted: Boolean;
    FStringType: TECStringType;

    procedure addName(ACh: char);
    procedure addValue(ACh: char);

    { property access }
    procedure setStringType(AType: TECStringType);

    public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ACh: char); inline;
    procedure Clear;
    function ParamAsString: String; inline;
    function IsEmpty: Boolean; inline;

    property Completed: Boolean read FCompleted;
    property StringType: TECStringType read FStringType write setStringType;

  end;

  //* valore, rappresenta una stringe dell' header

  TECValue = class
    private
    FName: string;
    FDocs: string;
    FValueList: TStringList;
    FValue: string;
    FMaxValue: Integer;
    FMinValue: Integer;
    FOptionName: string;
    //* parte iniziale di una linea di testo usata per la rigenerazione del file
    FLineHeader: string;
    //* parte terminale di una linea usata per le rigenerazione del testo
    FLineTail: string;
    FKind: TECValueKind;
    procedure parseInternal(AString: string);

    { property access }
    function getNameMagic: string; inline;
    function getOptions(AIndex: Integer): string; inline;
    function getActualValueIdx: Integer; inline;
    procedure setOptionName(AName: string);
    function getOptionName: string;
    public

    constructor Create;
    destructor Destroy; override;
{$IFDEF EXTENDED_DEBUG}
    procedure Trace;
{$ENDIF}
    procedure Parse(const AString: TECSplittedString);
    procedure Clear;
    procedure ValuesAssignTo(AList: TStrings); inline;
    function ValueAsString: string;
    {* nome della propriet� }
    property Name: string read FName;
    {* documnetazione della proprit� }
    property Docs: string read FDocs write FDocs;
    property NameMagic: string read getNameMagic;
    property Options[AIdx: Integer]: string read getOptions;
    property Value: string read FValue;
    property MaxValue: Integer read FMaxValue;
    property MinValue: Integer read FMinValue;
    property OptionName: string read getOptionName write setOptionName;
    property ActualValueIdx: Integer read getActualValueIdx;
    property Kind: TECValueKind read FKind;
  end;

  TECValueList = class(TObjectList)
    private
    function getValues(AIndex: integer): TECValue; inline;

    public
    function Find(AName: string): TECValue;
    property Values[AIndex: integer]: TECValue read getValues;
  end;

  {* Classe che rappresenta il file da processare }
  TECDataFile = class
    private
    FDataFile: TStringList;
    FValueList: TECValueList;
    FPartList: TObjectList;
    FBodyIndex: Integer;
    FInvalidString: Integer;
    FDocName: string;
    FFileName: string;

    function getValue(AIndex: Integer): TECValue; inline;
    function getCount: Integer;
    {* aggiunge una stringa di documentazione ad un valore }
    procedure addDocEntry(AString: string);
    function splitString(var ASplit: TECSplittedString; AString: string): Boolean;

    public
    constructor Create;
    destructor Destroy; override;
    {* Carica il file all' interno di una classe ed  effettua il parsing
       @AName: nome del file da caricare }
    procedure LoadFromFile(AName: string);
    {* Salva il file modificato
       @AName: nome del file da salvare }
    procedure SaveToFile(AName: string = ''); inline;
    {* Effettua tutte le sostituzioni }
    procedure ReplaceAll;

    {* sono  i valori di sostituzione all' interno del file }
    property ValueList: TECValueList read FValueList;
    property InvalidString: Integer read FInvalidString;
    property Count: Integer read getCount;
    property FileName: string read FFileName;
  end;


implementation

uses
  StrUtils,
  SiAuto,
  SmartInspect;

{ Exceptions ----------------------------------------------------------------- }

constructor EECException.Create(const AMsg: string);
begin
  inherited Create(AMsg);
end;

constructor EECInvalidString.Create(const AMsg: string);
begin
  inherited CreateFmt(kInvalidStringStr,[AMsg]);
end;

constructor EECInvalidIndex.Create;
begin
  inherited Create('Parametro senza indice');
end;

constructor EECInvalidOperation.Create(const AMsg: string);
begin
  inherited Create(AMsg);
end;

constructor EECNoDataFile.Create(const AMsg: string);
begin
  inherited Create(AMsg);
end;

{ TECStringBuilder ----------------------------------------------------------- }

procedure TECParamBuilder.addName(ACh: char);
begin  if FCompleted then
    Exit;

  if CharInSet(Char(Ord(ACh) or $20),[#$61..#$7a]) or
      CharInSet(ACh,[#$30..#$39,#$5f]) then
    FStringBuilder.Add(ACh)
  else if ACh = ',' then
    FCompleted := True;
end;

procedure TECParamBuilder.addValue(ACh: char);
begin
  if not FEscape then begin
    case ACh of
      '=': begin
             FPairComplete := True;
             FStringBuilder.Add(ACh);
           end;
      ',': begin
           if not FPairComplete and (FStringType = stPair) then
             FStringBuilder.Add('=');
             FCompleted := True;
           end;
      kEscapeChar: FEscape := True;
      '''','"': FQuote := not FQuote;
      ' ',#9: if FQuote and (FStringType = stValue) then
            FStringBuilder.Add(ACh);
      else
        FStringBuilder.Add(ACh);
    end;
  end else begin
    FEscape := False;
    if not ((ACh = ' ') or (ACh = #9)) or FQuote then
      FStringBuilder.Add(ACh);
  end;
end;

procedure TECParamBuilder.setStringType(AType: TECStringType);
begin
  Clear;
  FStringType := AType;
end;

constructor TECParamBuilder.Create;
begin
  FStringBuilder := TStringList.Create;
end;

{ VIRTUAL }
destructor TECParamBuilder.Destroy;
begin
  FStringBuilder.Free;
end;

{ INLINE }
procedure TECParamBuilder.Add(const ACh: char);
begin
  case FStringType of
    stValue,stPair: addValue(ACh);
    stName: addName(ACh);
  end;
end;

procedure TECParamBuilder.Clear;
begin
  FEscape := False;
  FQuote  := False;
  FCompleted := False;
  FPairComplete := False;
  FStringBuilder.Clear;
  FStringBuilder.LineBreak := '';
end;

{ INLINE }
function TECParamBuilder.ParamAsString: string;
begin
  Result := FStringBuilder.Text;
end;

{ INLINE }
function TECParamBuilder.IsEmpty: Boolean;
begin
  Result := FStringBuilder.Count = 0;
end;

{ TECValue ------------------------------------------------------------------- }


{ qui ho la stringa su chi effettuare il parser

  FORMATO STRING:
  kind string:  S,SYMNAME,value
  kind path:    P,SYMNAME,path
  kind file     F,SYMNAME,file
  kind range    R,SYMNAMe,value,min,max
  kind boolean  B,SYMNAME,value,onvalue,offvalue
  kind multiple M,SYMNAME,value,auto,name1=value1,name2=value2....

  NOTA: il kind e' il carattere 1
  NOTA: per i boolean il nome e' fissato a true per il primo e false per il secondo
}

procedure TECValue.parseInternal(AString: string);
var
  LParamBuilder: TECParamBuilder;
  LOptionName,
  LValueName: string;
  LAddValue: Boolean;
  LValueIdx,
  LStato: Integer;
  LFindComma,
  LNextState: Boolean;
  LCh: char;
begin
  LParamBuilder := TECParamBuilder.Create;
  try
    LStato := 0;
    LValueIdx := 0;
    LFindComma := False;
    FKind := vkUnknown;

    { aggiungo una virgola dummy come terminatore }
    AString := AString + ',';

    for LCh in AString do begin
      { cerco il campo }
      case LStato of
        0: { Kind }
          begin
            { determino il kind  }
            if FKind = vkUnknown then begin
              case LCh of
                'S': FKind := vkString;
                'P': FKind := vkPath;
                'F': FKind := vkFile;
                'B': FKind := vkBoolean;
                'M': FKind := vkMultiple;
                'R': FKind := vkRange;
              end;
            end;
            { quando trovo la virola passo allo stato succcessivo }
            if LCh = ',' then begin
              { verifico che sia stato impostato un kind valido }
              if FKind = vkUnknown then begin
                SiMain.LogWarning('TECVALUE: Invalid Kind',[AString]);
                raise EECInvalidString.Create('Invalid Kind');
              end;

              { eseguo le impostazioni per il prossimo stato }
              LParamBuilder.StringType := stName;
              { ok, next state }
              LStato := 1;
            end;
          end; { case 0 }
        1, { name }
        2: { value }
          begin
            LParamBuilder.Add(LCh);
            if LParamBuilder.Completed then begin
              case LStato of
                1: begin
                     { name }
                     FName := LParamBuilder.ParamAsString;
                     LParamBuilder.StringType := stValue;
                     LStato := 2;
                   end;
                2: begin
                     { value }
                     { nota qui uso una variabile transitoria perche' non abbiano
                       ancora caricato la tabe��a delle opzioni (se esiste) }
                     LOptionName := LParamBuilder.ParamAsString;
                     if Kind = vkMultiple then
                       LParamBuilder.StringType := stPair
                     else
                       LParamBuilder.StringType := stValue;
                     LParamBuilder.Clear;
                     LStato := 3;
                     LValueIdx := 0;
                   end;
              end; { case  }
            end; { end if }
          end; { end 2: }

          { value specific }

        3: case FKind of
              { nota da un punto di vista del valore string e path sono trattati in modo analogo }
              vkString,
              vkFile,
              vkPath: ;
              vkBoolean:
                begin
                  LParamBuilder.Add(LCh);
                  if LParamBuilder.Completed and (LValueIdx <= 1) then begin
                    LAddValue := true;
                    case LValueIdx of
                      0: LValueName := 'True'+'='+LParamBuilder.ParamAsString;
                      1: LValueName := 'False'+'='+LParamBuilder.ParamAsString
                      else
                        LAddValue := False;
                    end;
                    if LAddValue then
                      FValueList.Add(LValueName);
                    LParamBuilder.Clear;
                    Inc(LValueIdx);
                  end;
                end;

              vkMultiple:
                begin
                  LParamBuilder.Add(LCh);
                  if LParamBuilder.Completed then begin
                    FValueList.Add(LParamBuilder.ParamAsString);
                    LParamBuilder.Clear;
                  end;
                end;
              vkRange:
                begin
                  LParamBuilder.Add(LCh);
                  if LParamBuilder.Completed then
                    try
                      case LValueIdx of
                        0: FMinValue := StrToInt(LParamBuilder.ParamAsString);
                        1: FMaxValue := StrToInt(LParamBuilder.ParamAsString);
                      end;
                      LParamBuilder.Clear;
                      Inc(LValueIdx);
                    except
                      on EConvertError do begin
                        FMinValue := -MaxInt;
                        FMaxValue := MaxInt;
                      end;
                    end;
                end;
           end; { case stato 3,4 }

      end; { case }
    end;{ loop }

    { ho finito la tabella delle opzioni (se esiste) e' completa quindi
      imposto il nome dell'opzione e lascio la gestione all'handler della
      property }

    OptionName := LOptionName;

  finally
    LParamBuilder.Free;
  end;
end;


function TECValue.getNameMagic: string;
begin
  Result := kStrMagicVar + FName + kStrMagicVar;
end;

{ INLINE }
function TECValue.getOptions(AIndex: Integer): string;
begin
  Result := FValueList.Strings[AIndex];
end;

{ INLINE }
function TECValue.getActualvalueIdx: Integer; 
begin
  if FKind in [vkPath,vkFile,vkString] then
    raise EECInvalidIndex.Create;
  Result := FValueList.IndexOf(FValue);

  if FValueList.IndexOf(FValue) < 0 then
    EECInvalidString.Create('valore non valido');
end;

procedure TECValue.setOptionName(AName: string);
var
  LValueIdx: Integer;
begin
  if FKind in [vkBoolean,vkMultiple] then
    FValue := FValueList.Values[AName]
  else
    { per i tipi vkString, vkPath, vkFile, vkRenge il valore corrisponde al nome }
    FValue := AName;

  FOptionName := AName;
end;

function TECValue.getOptionName: string;
begin
  if FKind in [vkBoolean,vkMultiple] then
    Result := FOptionName
  else
    result := FValue;
end;

constructor TECValue.Create;
begin
  FValueList := TStringList.Create;
end;

destructor TECValue.Destroy;
begin
  FValueList.Free;
end;

{$IFDEF EXTENDED_DEBUG}

procedure TECValue.Trace;
var
  I: Integer;
  LContext: TSiInspectorViewerContext;
  LKindName: string;
begin
  LContext := TSiInspectorViewerContext.Create;
  try
    case FKind of
      vkString:  LKindName := 'vkString';
      vkPath:    LKindName := 'vkPath';
      vkFile:    LKindName := 'vkPath';
      vkBoolean: LKindName := 'vkBoolean';
      vkMultiple: LKindName := 'vkMultiple';
      vkRange:   LKindName := 'vkRange';
      else
        LKindName := '*** UNKNOWN ***';
    end;

    LContext.StartGroup('Info');
    LContext.AppendKeyValue('LineHeader',FLineHeader);
    LContext.AppendKeyValue('KindName',LKindName);
    LContext.AppendKeyValue('OptionName',OptionName);
    LContext.AppendKeyValue('Value',Value);
    LContext.AppendKeyValue('MaxValue',IntTostr(FMaxValue));
    LContext.AppendKeyValue('MinValue',IntTostr(FMinValue));

    if FValueList <>  nil then begin
      LContext.StartGroup('ValueList');
      for I := 0 to FValueList.Count - 1 do
        LContext.AppendkeyValue('Value.'+IntToStr(I),FValueList[I]);
    end;

    SiMain.LogCustomContext(lvDebug,Format('TECValue Dump ''%s''',[FName]), ltText, LContext);
  finally
    LContext.Free;
  end;
end;
{$ENDIF}

procedure TECValue.Parse(const AString: TECSplittedString);
begin
  SiMain.LogVerbose('VALUE: Str:''%s''',[AString.ContentStr]);
  FValueList.QuoteChar := '''';
  FLineHeader := AString.StartStr;
  FLineTail   := AString.EndStr;
  parseInternal(AString.ContentStr);
end;

procedure TECValue.Clear;
begin
  FValueList.Clear;
end;

procedure TECValue.ValuesAssignTo(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FValueList.Count - 1 do
    AList.Add(FValueList.Names[I]);
end;

{ B,prova,true,true,false }
function TECValue.ValueAsString: string;
var
  I: Integer;
  LKindChar: Char;
  LList,
  LListESc: TStringList;

  function doEscape(AString: string): string;
  var
    _LCh: Char;
  begin
    LListEsc.Clear;
    for _LCh in AString do begin
      if CharInSet(_LCh,[kEscapeChar,',']) then
        LListEsc.Add(kEscapeChar);

      LListEsc.Add(_LCh);
    end;
    Result := LListEsc.Text;
  end;

begin
  LList := TStringList.Create;
  LListEsc := TStringList.Create;
  LListEsc.LineBreak := '';
  try
    case Kind of
      vkString:   LList.Add('S');
      vkPath:     LList.Add('P');
      vkFile:     LList.Add('F');
      vkBoolean:  LList.Add('B');
      vkMultiple: LList.Add('M');
      vkRange:    LList.Add('R');
    end;
    LList.Add(FName);
    LList.Add(FOptionName);
    if FValueList.Count <> 0 then begin
      case Kind of
        vkRange: begin
          LList.Add(IntToStr(FMinValue));
          LList.Add(IntToStr(FMaxValue));
        end;

        vkMultiple: begin
          for I := 0 to FValueList.Count - 1 do
            LList.Add(doEscape(FValueList.Strings[I]));
        end;
        vkBoolean: begin
            LList.Add(doEscape(FValueList.ValueFromIndex[0]));
            LList.Add(doEscape(FValueList.ValueFromIndex[1]));
          end;
      end;
    end;
    Result := FLineHeader + ' ' + LList.CommaText;
    if FLinetail <> '' then
      Result := Result + ' ' + FLineTail;
    SiMain.LogDebug('TECValue: ValueAsString = %s',[Result]);
  finally
    LList.Free;
    LListEsc.Free;
  end;
end;

{ TECValueList --------------------------------------------------------------- }

{ INLINE }
function TECValueList.getValues(AIndex: Integer): TECValue;
begin
  Result := inherited Items[AIndex] as TECValue;
end;

function TECValueList.Find(AName: string): TECValue;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do begin
    if Values[I].Name = AName then begin
      Result := Items[I] as TECValue;
      Break;
    end;
  end;
end;

{ TECDataFile ---------------------------------------------------------------- }

function TECDataFile.getValue(AIndex: Integer): TECValue;
begin
  Result := FValueList.Values[AIndex];
end;

function TECDataFile.getCount: Integer;
begin
  Result := FValueList.Count;
end;

procedure TECDataFile.addDocEntry(AString: string);
var
  LPos: Integer;
  LName: string;
  LClearLastDoc: Boolean;
  LDocString: string;
  LValue: TECValue;
begin
  { prendo il nome e la stringa di documentazione dell'entry }
  LPos := Pos(kDocSeparator,AString);
  if LPos > 0 then begin
    LName := LeftStr(AString,LPos-1);
    LDocString := RightStr(AString,Length(AString)-(LPos+1));
    LClearLastDoc := true;
    FDocName := LName;
  end else begin
    LClearLastDoc := false;
    LDocString := AString;
    LName := FDocName;
  end;

  { prendo l'entry }
  LValue := FValueList.Find(LName);

  { aggiungo la documentazione }
  if LValue <> nil then begin
    if LClearLastDoc then
      LValue.FDocs := '';

    LValue.FDocs := LValue.FDocs + Trim(LDocString);
  end;
end;

function TECDataFile.splitString(var ASplit: TECSplittedString; AString: string): Boolean;
var
  LPos: Integer;
  LEndPos: Integer;
  LStartMarker: string;
  LEndMarker: string;
begin
  LStartMarker := ASplit.StartStr;
  LEndMarker := ASplit.EndStr;
  Result := False;

  LPos := Pos(LStartMarker,AString);
  LEndPos := Pos(LEndMarker,AString);

  if LPos > 0 then begin
    Inc(LPos,Length(LStartMarker));
    ASplit.StartStr := Trim(LeftStr(AString,LPos));

    if LEndPos > 0 then begin
      ASplit.EndStr := Trim(RightStr(AString,Length(AString)-LEndPos+1));
      ASPlit.ContentStr := Trim(MidStr(AString,Lpos,LEndPos-LPos));
    end else begin
      ASplit.EndStr := '';
      ASPlit.ContentStr := Trim(RightStr(AString,Length(AString)-LPos));
    end;
    Result := True;
  end;
end;

constructor TECDataFile.Create;
begin
  FDataFile  := TStringList.Create;
  FValueList := TECValueList.Create;
end;

{ VIRTUAL }
destructor TECDataFile.Destroy;
begin
  FValueList.Free;
  FDataFile.Free;
end;

procedure TECDataFile.LoadFromFile(AName: string);
var
  LSplit: TECSplittedString;
  LIndex: Integer;
  LValue: TECValue;
  LTerminate: Boolean;
begin
  try
    FFileName := AName;
    FDataFile.LoadFromFile(AName);
    FValueList.Clear;

    if FDataFile.Count = 0 then
      Exit;

    { processo header }
    FBodyIndex := 0;
    FInvalidString := 0;
    LValue := nil;
    LTerminate := False;
    repeat
      { verifico i marker per il processo }
      LSplit.StartStr := kStrHeader;
      LSplit.EndStr := kStrEnd;
      if splitString(LSplit,FDataFile.Strings[FBodyIndex]) then begin
        if LValue = nil then
          LValue := TECValue.Create
        else
          LValue.Clear;

        try
          LValue.Parse(LSplit);
{$IFDEF EXTENDED_DEBUG}
          LValue.Trace;
{$ENDIF}
          FValueList.Add(LValue);
          LValue := nil;
          { ho trovato almeno un entry valida, ora ho bisogno di un marker di fine }
          LTerminate := False;
        except on EECInvalidString do
          Inc(FInvalidString);
        end;
      end;

      { verifico i marker per la documentazione }
      LSplit.StartStr := kStrDocHeader;
      LSplit.EndStr := kStrEnd;

      if splitString(LSplit,FDataFile.Strings[FBodyIndex]) then
        { NOTA: le stringhe di documentazione sono immutabili rispetto al tool
                quindi non conservo informazioni aggiuntive }
        addDocEntry(Trim(LSplit.ContentStr));

      { verifico i marker di terminazione }
      if Pos(kFileHeaderEnd,FDataFile.Strings[FBodyIndex]) > 0 then
        LTerminate := True;
      Inc(FBodyIndex);
    until (LTerminate) or (FBodyIndex = FDataFile.Count);

  except
    { getione delle eccezioni }
    on E: Exception do begin
      if E is EOutOfmemory then
        SiMain.LogWarning('Out of memory')
      else
        SiMain.LogException;
      FDataFile.Clear;
      FValueList.Clear;
      raise;
    end;
  end;
end;

{ INLINE }
procedure TECDataFile.SaveToFile(AName: string);
begin
  if AName = '' then
    AName := FFileName;
  FDataFile.SaveToFile(AName);
end;

procedure TECDataFile.ReplaceAll;
var
  J,
  LCurrentLineIdx: Integer;
  LTerminated: Boolean;
  LNewString: string;
  LSplit: TECSplittedString;

{$IFDEF EXTENDED_DEBUG}
  dbgI: Integer;
  dbgStringList: TStringList;
{$ENDIF}
begin
  { Write header
    Si tratta di una modifica, non di una generazione. Cambio solo le linee
    con il marker perche prima potrebbero esserci delle linee "normali" }

  LCurrentLineIdx := 0;
  J := 0;
  LTerminated := false;
  while (LCurrentLineIdx < FDataFile.Count) and not LTerminated  do begin
    { verifico se devo fare l'aggioramento di un valore all' interno dell' header }
    if (Pos(kStrHeader,FDataFile.Strings[LCurrentLineIdx]) > 0) and
       (J < FValueList.Count) then begin
      FDataFile.Strings[LCurrentLineIdx] := FValueList.Values[J].ValueAsString;
      Inc(J);
    end;
    { verifico se trovo il marker di fine }
    if Pos(kFileHeaderEnd,FDataFile.Strings[LCurrentLineIdx]) > 0 then
      LTerminated := true;
    Inc(LCurrentLineIdx);
  end;

{$IFDEF EXTENDED_DEBUG}
  dbgStringList := TStringList.Create;
  try
    for dbgI := 0 to FValueList.Count - 1 do
      dbgStringList.Add(FDataFile.Strings[dbgI]);
    SiMain.LogStringList(lvDebug,Format('Header Trace (cnt=%d)',[dbgStringList.Count]),dbgStringList);
  finally
    dbgStringList.Free;
  end;
{$ENDIF}
  { cambio il file }
  { vedo se ho una linea marcata.
    Nota il valore di LCurrentLineIdx � quello rimasto impostato dall' operazione
    precedente, in modo che processiamo la prima linea successiva all'header }
  repeat
    LSplit.StartStr := kStrHeader;
    LSplit.EndStr   := kStrEnd;
    if splitString(LSplit,FDataFile.Strings[LCurrentLineIdx]) then begin
      J := 0;
      LTerminated := False;
      while (J < FValueList.Count) and not LTerminated do begin
        LNewString := ReplaceStr(
          LSplit.ContentStr,
          FValueList.Values[J].NameMagic,
          FValueList.Values[J].Value);
        if LNewString <> LSplit.ContentStr then
          LTerminated := True;
        Inc(J);
      end;
        Inc(LCurrentLineIdx);

      if FDataFile.Count = LCurrentLineIdx then
        FDataFile.Add(LNewString)
      else
        FDataFile.Strings[LCurrentLineIdx] := LNewString;
    end;
    Inc(LCurrentLineIdx);
  until LCurrentLineIdx = FDataFile.Count;
end;

end.
