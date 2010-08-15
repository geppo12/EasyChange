unit UCore;

interface

uses
  SysUtils,
  SmartInspect,
  SiAuto,
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
    public
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

  EECInvalidValue = class(EECException)
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
    FParamIndex: Integer;
    FStringType: TECStringType;

    procedure addName(ACh: char);
    procedure addValue(ACh: char);

    { property access }
    procedure setStringType(AType: TECStringType);
    procedure clear;

    public
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ACh: char); inline;
    procedure NewParameter;
    procedure Reset;
    function ParamAsString: String; inline;
    function IsEmpty: Boolean; inline;

    property Completed: Boolean read FCompleted;
    property ParamIndex: Integer read FParamIndex;
    property StringType: TECStringType read FStringType write setStringType;
  end;

  {* valore, rappresenta una stringe dell' header }

  TECValue = class
    strict private
    FValue: string;

    private
    FName: string;
    FDocs: string;
    {* parte iniziale di una linea di testo usata per la rigenerazione del file }
    FLineHeader: string;
    {* parte terminale di una linea usata per le rigenerazione del testo }
    FLineTail: string;
    FKind: TECValueKind;
    procedure parseInternal(AString: string);
    class function getKind(ADataString: string): TECValueKind;

    { property access }
    function getNameMagic: string; inline;
    {* Imposta il valore
       @param AValue: valore attuale  }
    procedure setValue(AValue: string); inline;

    protected
    FParamBuilderType: TECStringType;

    {* Ritorna il valore attuale, il valore ritornato dipende dalla sottoclasse
       @returns valore dell'oggetto TECValue }
    function getInternalValue: string; virtual;
{$IFDEF EXTENDED_DEBUG}
    procedure internalTrace(AContext: TSiInspectorViewerContext); virtual;
{$ENDIF}
    function validate(AData: String): Boolean; virtual;
    {* Usata da ValueAsString aggiunge i valori alla stringa
       @param AList: lista dove aggingere i valori della stringa in uscita }
    procedure valueStringFactory(AList: TStringList); virtual;
    {* Aggiorna il value con dati specifici della sottoclasse
       @param AParamBuilder: cotenitore dei parametri per i dati specifici }
    procedure updateSpecificData(AParamBuilder: TECParamBuilder); virtual;
    {* Effattua l'escape della virgola nelle stringe
       @param AString: stringa con virgole di cui effettuare l'escape
       @result stringa con le virole preposte di simbolo di escape }
    function doEscape(AString: string): string;

    public
    class function CreateValue(ASplittedString: TECSplittedString): TECValue;
    constructor Create(AKind: TECValueKind);
{$IFDEF EXTENDED_DEBUG}
    procedure Trace;
{$ENDIF}
    procedure Parse(const AString: TECSplittedString);
    function ValueAsString: string;
    {* nome della proprietà }
    property Name: string read FName;
    {* documnetazione della proprità }
    property Docs: string read FDocs write FDocs;
    property NameMagic: string read getNameMagic;
    property Value: string read FValue write setValue;
    property Kind: TECValueKind read FKind;
  end;

  TECValueRange = class(TECValue)
    private
    FMaxValue: Integer;
    FMinValue: Integer;

    protected
{$IFDEF EXTENDED_DEBUG}
    procedure internalTrace(AContext: TSiInspectorViewerContext); override;
{$ENDIF}
    function validate(AString: string): Boolean; override;
    procedure valueStringFactory(AList: TStringList); override;
    procedure updateSpecificData(AParamBuilder: TECParamBuilder); override;

    public
    constructor Create;
  end;

  TECValueMulti = class(TECValue)
    private
    FOptionList: TStringList;

    function getActualValueIdx: Integer; inline;
    function getOptions(AIndex: Integer): string; inline;

    protected
    function getInternalValue: string; override;

{$IFDEF EXTENDED_DEBUG}
    procedure internalTrace(AContext: TSiInspectorViewerContext); override;
{$ENDIF}
    procedure valueStringFactory(AList: TStringList); override;
    procedure updateSpecificData(AParamBuilder: TECParamBuilder); override;

    public
    constructor Create(AKind: TECValueKind);
    destructor Destroy; override;
    procedure ValuesAssignTo(AList: TStrings); inline;
    property ActualValueIdx: Integer read getActualValueIdx;
    property Options[AIdx: Integer]: string read getOptions;
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
    {* aggiunge una stringa di documentazione ad un valore
       @param AString: stringa di documentazione da aggiungere }
    procedure addDocEntry(AString: string);
    {* Crea e carica un valore dalla stringa fornita
       @param ASplittedString: record con le informazioni per creare il valore }
    procedure loadValue(ASplittedString: TECSplittedString);
    {* divide in stringa in header, content e footer.
       @param ASplit: record che contiene la stringa splittata
       @param AString: stringa da splittare
       @return vero se trava marker compatibili per estrarre una stringa }
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
  TypInfo,
  StrUtils;

{$REGION 'Exceptions'}
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

constructor EECInvalidValue.Create(const AMsg: string);
begin
  inherited Create(AMsg);
end;
{$ENDREGION}

{$REGION 'TECStringBuilder'}
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
  clear;
  FStringType := AType;
end;

procedure TECParamBuilder.clear;
begin
  FEscape := False;
  FQuote  := False;
  FCompleted := False;
  FPairComplete := False;
  FStringBuilder.Clear;
  FStringBuilder.LineBreak := '';
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

procedure TECParamBuilder.NewParameter;
begin
  clear;
  Inc(FParamIndex);
end;

procedure TECParamBuilder.Reset;
begin
  clear;
  FParamIndex := 0;
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
{$ENDREGION}

{$REGION 'TECValue'}
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
  LOptionName: string;
  LStato: Integer;
  LFindComma,
  LNextState: Boolean;
  LCh: char;
begin
  LParamBuilder := TECParamBuilder.Create;
  try
    LStato := 0;
    LFindComma := False;

    { aggiungo una virgola dummy come terminatore }
    AString := AString + ',';

    for LCh in AString do begin
      { cerco il campo }
      case LStato of
        0: { Kind }
          begin
            { quando trovo la virola passo allo stato succcessivo }
            if LCh = ',' then begin
              { verifico che sia stato impostato un kind valido }
              if FKind = vkUnknown then begin
                SiMain.LogWarning('TECVALUE: Invalid Kind',[AString]);
                raise EECInvalidString.Create('Invalid Kind');
              end;

              { eseguo le impostazioni per il prossimo stato }
              LParamBuilder.Reset;
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
              { name }
                1: begin
                     FName := LParamBuilder.ParamAsString;
                     LParamBuilder.StringType := stValue;
                     LStato := 2;
                   end;

                { value }
                2: begin
                     { imposto la label attuale che può essere il valore vero
                       e proprio oppure una label simbolica associata al valore }
                     FValue := LParamBuilder.ParamAsString;

                     { imposto il builder on il tipo di stringa relativa al tipo
                       specifico di valore da processare }
                     LParamBuilder.StringType := FParamBuilderType;
                     LParamBuilder.Reset;
                     LStato := 3;
                   end;
              end; { case interno }
            end; { end if }
          end; { end 2: }

        { value specific }
        3: begin
          LParamBuilder.Add(LCh);
          updateSpecificData(LParamBuilder);
        end;
      end; { case }
    end;{ loop }

  finally
    LParamBuilder.Free;
  end;
end;

class function TECValue.getKind(ADataString: string): TECValueKind;
begin
  Result := vkUnknown;
  if Length(ADataString) >= 0 then
    case ADataString[1] of
      'S': Result := vkString;
      'P': Result := vkPath;
      'F': Result := vkFile;
      'B': Result := vkBoolean;
      'M': Result := vkMultiple;
      'R': Result := vkRange;
    end;
end;

function TECValue.getNameMagic: string;
begin
  Result := kStrMagicVar + FName + kStrMagicVar;
end;

procedure TECValue.setValue(AValue: string);
begin
  SiMain.LogDebug('Name %s, Value = %s',[FName,AValue]);
  if validate(AValue) then
    FValue := AValue
  else
    raise EECInvalidValue.Create(AValue);
end;

function TECValue.getInternalValue: string;
begin
  Result := FValue;
end;

procedure TECValue.internalTrace(AContext: TSiInspectorViewerContext);
begin
  AContext.StartGroup('Rooot Info');
  AContext.AppendKeyValue('LineHeader',FLineHeader);
  AContext.AppendKeyValue('KindName',GetEnumName(TypeInfo(TECValueKind),ord(FKind)));
  AContext.AppendKeyValue('Value',FValue);
  AContext.AppendKeyValue('Internal Value',getInternalValue);
end;

function TECValue.validate(AData: String): Boolean;
begin
  { il dato è sempre valido, a mno che questa funzione non venga
    ridefinita dai discendenti }
  Result := True;
end;

procedure TECValue.valueStringFactory(AList: TStringList);
begin
  { implementata dai discendenti }
end;

procedure TECValue.updateSpecificData(AParamBuilder: TECParamBuilder);
begin
  { implementata dai discendenti }
end;

function TECValue.doEscape(AString: string): string;
var
  LCh: Char;
  LListEsc: TStringList;
begin
  Result := '';
  LListEsc := TStringList.Create;
  LListEsc.LineBreak := '';
  try
    for LCh in AString do begin
      if CharInSet(LCh,[kEscapeChar,',']) then
        LListEsc.Add(kEscapeChar);

      LListEsc.Add(LCh);
    end;
    Result := LListEsc.Text;
  finally
    LListEsc.Free;
  end;
end;

class function TECValue.CreateValue(ASplittedString: TECSplittedString): TECValue;
var
  LKind: TECValueKind;
begin
  Result := nil;
  { get kind part }
  LKind := getKind(ASplittedString.ContentStr);
  case LKind of
    vkUnknown: raise EECInvalidString.Create('Tipo di valore sconosciuto nell''header');

    vkString,
    vkPath,
    vkFile:     Result := TECValue.Create(LKind);

    vkBoolean,
    vkMultiple: Result := TECValueMulti.Create(LKind);

    vkRange:    Result := TECValueRange.Create;
  end;

  Result.Parse(ASplittedString);
end;

constructor TECValue.Create(AKind: TECValueKind);
begin
  FKind := AKind;
  FParamBuilderType := stValue;
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
    internalTrace(LContext);
    SiMain.LogCustomContext(lvDebug,Format('%s Dump ''%s''',[ClassName,FName]), ltText, LContext);
  finally
    LContext.Free;
  end;
end;
{$ENDIF}

procedure TECValue.Parse(const AString: TECSplittedString);
begin
  SiMain.LogVerbose('VALUE: Str:''%s''',[AString.ContentStr]);
  FLineHeader := AString.StartStr;
  FLineTail   := AString.EndStr;
  parseInternal(AString.ContentStr);
end;

{ B,prova,true,true,false }
function TECValue.ValueAsString: string;
var
  I: Integer;
  LKindChar: Char;
  LList,
  LListESc: TStringList;

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
    LList.Add(FValue);
    { aggiungo alla lista la parti relative ad ogni sottoclasse }
    valueStringFactory(LList);

    { compongo il risultato }
    Result := FLineHeader + ' ' + LList.CommaText;
    if FLinetail <> '' then
      Result := Result + ' ' + FLineTail;
    SiMain.LogDebug('TECValue: ValueAsString = %s',[Result]);
  finally
    LList.Free;
    LListEsc.Free;
  end;
end;
{$ENDREGION}

{$REGION 'TECValueRange'}
{$IFDEF EXTENDED_DEBUG}
procedure TECValueRange.internalTrace(AContext: TSiInspectorViewerContext);
begin
  inherited;
  AContext.StartGroup('Range Info');
  AContext.AppendKeyValue('MaxVaue',FMaxValue);
  AContext.AppendKeyValue('MinVaue',FMinValue);
end;
{$ENDIF}

function TECValueRange.validate(AString: string): Boolean;
var
  LValue: Integer;
begin
  Result := False;
  try
    LValue := StrToInt(AString);
    Result := (LValue >= FMinValue) and (LValue <= FMaxValue);
  except
    { l' eccezione di conversione non fa niente. La funziona ritorna
      false perche' non e' riuscita a fare il confronto }
    on EConvertError do ;
  end;
end;

procedure TECValueRange.valueStringFactory(AList: TStringList);
begin
  AList.Add(IntToStr(FMinValue));
  AList.Add(IntToStr(FMaxValue));
end;

procedure TECValueRange.updateSpecificData(AParamBuilder: TECParamBuilder);
begin
  if AParamBuilder.Completed then
    try
      case AParamBuilder.ParamIndex of
        0: FMinValue := StrToInt(AParamBuilder.ParamAsString);
        1: FMaxValue := StrToInt(AParamBuilder.ParamAsString);
      end;
      AParamBuilder.NewParameter;
    except
      on EConvertError do
        case AParamBuilder.ParamIndex of
          0: FMinValue := -MaxInt;
          1: FMaxValue := MaxInt;
        end;
    end;
end;

constructor TECValueRange.Create;
begin
  inherited Create(vkRange);
end;
{$ENDREGION}

{$REGION 'TECValueMulti'}

{ INLINE }
function TECValueMulti.getActualValueIdx: Integer;
begin
  Result := FOptionList.IndexOfName(Value);

  if Result < 0 then
    EECInvalidString.Create('valore non valido');
end;

{ INLINE }
function TECValueMulti.getOptions(AIndex: Integer): string;
begin
  Result := FOptionList.Strings[AIndex];
end;

function TECValueMulti.getInternalValue: string;
begin
  { in questa classe il valore quello assocciato al nome dell'opzione nella
    tabella delle opzioni }
  Result := FOptionList.Values[Value];
end;

{$IFDEF EXTENDED_DEBUG}
procedure TECValueMulti.internalTrace(AContext: TSiInspectorViewerContext);
var
  I: Integer;
begin
  inherited;
  AContext.StartGroup('Multi Info');
  for I := 0 to FOptionList.Count - 1 do
    AContext.AppendkeyValue('Value.'+IntToStr(I),FOptionList[I]);
end;
{$ENDIF}

procedure TECValueMulti.valueStringFactory(AList: TStringList);
var
  I: Integer;
begin
  case Kind of
    vkMultiple: begin
      for I := 0 to FOptionList.Count - 1 do
        AList.Add(doEscape(FOptionList.Strings[I]));
    end;

    vkBoolean:
      if FOptionList.Count >= 2 then begin
        AList.Add(doEscape(FOptionList.ValueFromIndex[0]));
        AList.Add(doEscape(FOptionList.ValueFromIndex[1]));
      end;
  end;
end;

procedure TECValueMulti.updateSpecificData(AParamBuilder: TECParamBuilder);
var
  LAddValue: Boolean;
  LValueName: string;
begin
  case Kind of
    vkBoolean:
      begin
        if AParamBuilder.Completed and (AParamBuilder.ParamIndex <= 1) then begin
          LAddValue := true;
          case AParamBuilder.ParamIndex of
            0: LValueName := 'True'+'='+AParamBuilder.ParamAsString;
            1: LValueName := 'False'+'='+AParamBuilder.ParamAsString
            else
              LAddValue := False;
          end;
          if LAddValue then
            FOptionList.Add(LValueName);
          AParamBuilder.NewParameter;
        end;
      end;

      vkMultiple:
        begin
          if AParamBuilder.Completed then begin
            FOptionList.Add(AParamBuilder.ParamAsString);
            AParamBuilder.NewParameter;
          end;
        end;
  end;
end;

constructor TECValueMulti.Create(AKind: TECValueKind);
begin
  inherited;
  FOptionList := TStringList.Create;
  { override del tipo di builder per il valore creato durante il parsing }
  if AKind = vkMultiple then
    FParamBuilderType := stPair;
end;

destructor TECValueMulti.Destroy;
begin
  FOptionList.Free;
  inherited;
end;

procedure TECValueMulti.ValuesAssignTo(AList: TStrings);
var
  I: Integer;
begin
  AList.Clear;
  for I := 0 to FOptionList.Count - 1 do
    AList.Add(FOptionList.Names[I]);
end;


{$ENDREGION}

{$REGION 'TECValueList'}
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
{$ENDREGION}

{$REGION 'TECDataFile'}

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

procedure TECDataFile.loadValue(ASplittedString: TECSplittedString);
var
  LValue: TECValue;
begin
  if splitString(ASplittedString,FDataFile.Strings[FBodyIndex]) then begin
    try
      LValue := TECValue.CreateValue(ASplittedString);

{$IFDEF EXTENDED_DEBUG}
      LValue.Trace;
{$ENDIF}
      FValueList.Add(LValue);
    except
      on EECInvalidString do
        Inc(FInvalidString);
      on Exception do begin
        SiMain.LogException;
        raise;
      end;
    end;
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

destructor TECDataFile.Destroy;
begin
  FValueList.Free;
  FDataFile.Free;
end;

procedure TECDataFile.LoadFromFile(AName: string);
var
  LSplit: TECSplittedString;
  LIndex: Integer;
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
    LTerminate := False;
    repeat
      { verifico i marker per i valori }
      LSplit.StartStr := kStrHeader;
      LSplit.EndStr := kStrEnd;
      loadValue(LSplit);

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
    Nota il valore di LCurrentLineIdx è quello rimasto impostato dall' operazione
    precedente, in modo che processiamo la prima linea successiva all'header }
  repeat
    LSplit.StartStr := kStrHeader;
    LSplit.EndStr   := kStrEnd;
    { verifico di avere una linea con dei marker }
    if splitString(LSplit,FDataFile.Strings[LCurrentLineIdx]) then begin
      { cerco il valore (per nome }
      J := 0;
      LTerminated := False;
      { faccio un replace string su tutte le variabili del database.
        TODO -cFIXME : metodo di sostiruzione 'brutto', da cambiare }
      while (J < FValueList.Count) and not LTerminated do begin
        LNewString := ReplaceStr(
          LSplit.ContentStr,
          FValueList.Values[J].NameMagic,
          FValueList.Values[J].getInternalValue);
        if LNewString <> LSplit.ContentStr then
          LTerminated := True;
        Inc(J);
      end;
        Inc(LCurrentLineIdx);

      { se ho fatto una terminazioen forzata la stringa e stata aggiornata
        e quindi va sostituita, altrimenti LNewString non è cambiata e quindi
        non va modificata nel codice }
      if LTerminated then begin
        if FDataFile.Count = LCurrentLineIdx then
          FDataFile.Add(LNewString)
        else
          FDataFile.Strings[LCurrentLineIdx] := LNewString;
      end;
    end;
    Inc(LCurrentLineIdx);
  until LCurrentLineIdx = FDataFile.Count;
end;
{$ENDREGION}
end.
