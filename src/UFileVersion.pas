unit UFileVersion;

interface

type
  TVerMode = (
    k4DigitPlain, { modello '0.0.0.0' }
    k3DigitWithBeta { modello con indicazione beta 0.0.0beta0 (beta visualizzato se attivo flag beta}
  );

function VersionInformation(AVerMode: TVerMode; ABeta: Boolean = false): string;

implementation

uses Forms,Windows,SysUtils;

function VersionInformation(AVerMode: TVerMode; ABeta: Boolean): string;
var
  sFileName: string;
  LBuild: Integer;
  VerInfoSize: DWORD;
  VerInfo: Pointer;
  VerValueSize: DWORD;
  VerValue: PVSFixedFileInfo;
  Dummy: DWORD;
begin
  LBuild := 0;
  sFileName := Application.ExeName;
  VerInfoSize := GetFileVersionInfoSize(PChar(sFileName), Dummy);
  GetMem(VerInfo, VerInfoSize);
  GetFileVersionInfo(PChar(sFileName), 0, VerInfoSize, VerInfo);
  VerQueryValue(VerInfo, '\', Pointer(VerValue), VerValueSize);
  with VerValue^ do
  begin
    Result := IntToStr(dwFileVersionMS shr 16);
    Result := Result + '.' + IntToStr(dwFileVersionMS and $FFFF);
    Result := Result + '.' + IntToStr(dwFileVersionLS shr 16);
    if AVerMode = k4DigitPlain then
      Result := Result + '.' + IntToStr(dwFileVersionLS and $FFFF)
    else if (AVerMode = k3DigitWithBeta) and ABeta then begin
      LBuild := dwFileVersionLS and $FFFF;

      if (LBuild div 100) = 0 then
        Result := Result + 'beta' + IntToStr(LBuild)
      else
        Result := Result + 'RC' + IntToStr(LBuild mod 100)
    end;
  end;
  FreeMem(VerInfo, VerInfoSize);
end;



end.
