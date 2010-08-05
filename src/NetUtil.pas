{ se voglio passare a net il codice qui dentro maschera un po' di cose }
unit NetUtil;

interface

type
{ adapter for .net }
  TStringBuilder = class
    private
    FString: String;

    function getLen: Integer; inline;
    procedure setLen(ALen: Integer); inline;
    function getChar(AIndex: Integer): Char; inline;

    public
    constructor Create(ASize: Integer); overload;
    procedure Append(const AString: string); overload;  inline;
    procedure Append(const ACh: Char); overload; inline;
    function ToString: string; inline;

    property Length: Integer read getLen write setLen;
    property Chars[AIndex: Integer]: Char read getChar;
  end;


implementation

uses StrUtils;

{ TStringBuilder ------------------------------------------------------------- }


{ dummy constructor for .Net compatibility }
constructor TStringBuilder.Create(ASize: Integer);
begin
  inherited Create;
end;

{ INLINE }
function TStringBuilder.getLen: Integer;
begin
  Result := System.Length(FString);
end;

procedure TStringBuilder.setLen(ALen: Integer);
begin
  if ALen = 0 then
    FString := ''
  else
    FString := LeftStr(FString,ALen);
end;

{ INLINE }
function TStringBuilder.getChar(AIndex: Integer): Char;
begin
  Result := FString[AIndex];
end;

{ INLINE }
procedure TStringBuilder.Append(const AString: string);
begin
  FString := FString + AString;
end;

procedure TStringBuilder.Append(const ACh: Char);
begin
  FString := FString + string(ACh);
end;

{ INLINE }
function TStringBuilder.ToString;
begin
  Result := FString;
end;



end.
