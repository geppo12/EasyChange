program EasyChange;



uses
  Forms,
  UMain in 'UMain.pas' {fmMain},
  UCore in 'UCore.pas',
  UFileVersion in 'UFileVersion.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TfmMain, fmMain);
  Application.Run;
end.
