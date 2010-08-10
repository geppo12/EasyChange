object fmMain: TfmMain
  Left = 0
  Top = 0
  Caption = 'Easy Change'
  ClientHeight = 505
  ClientWidth = 572
  Color = clBtnFace
  DragMode = dmAutomatic
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  KeyPreview = True
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  OnKeyDown = FormKeyDown
  OnResize = FormResize
  OnShow = FormShow
  DesignSize = (
    572
    505)
  PixelsPerInch = 96
  TextHeight = 13
  object sgProperty: TStringGrid
    Left = 8
    Top = 8
    Width = 320
    Height = 378
    Anchors = [akLeft, akTop, akBottom]
    ColCount = 2
    FixedCols = 0
    FixedRows = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing]
    ScrollBars = ssVertical
    TabOrder = 3
    OnSelectCell = sgPropertySelectCell
    OnSetEditText = sgPropertySetEditText
    ColWidths = (
      78
      73)
  end
  object btnOk: TButton
    Left = 487
    Top = 472
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Process'
    TabOrder = 0
    OnClick = btnOkClick
  end
  object cbMultiple: TComboBox
    Left = 120
    Top = 209
    Width = 145
    Height = 21
    Style = csDropDownList
    DragMode = dmAutomatic
    TabOrder = 1
    Visible = False
    OnSelect = cbMultipleSelect
  end
  object btnPath: TButton
    Left = 173
    Top = 264
    Width = 23
    Height = 23
    Anchors = [akTop, akRight]
    Caption = '...'
    TabOrder = 2
    Visible = False
    OnClick = btnPathClick
  end
  object btnExit: TButton
    Left = 406
    Top = 472
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Exit'
    TabOrder = 4
    OnClick = btnExitClick
  end
  object mDoc: TMemo
    Left = 8
    Top = 392
    Width = 554
    Height = 65
    Anchors = [akLeft, akRight]
    Lines.Strings = (
      '')
    ReadOnly = True
    TabOrder = 5
  end
  object cbUseProject: TCheckBox
    Left = 8
    Top = 463
    Width = 87
    Height = 17
    Caption = 'Use Project'
    Checked = True
    State = cbChecked
    TabOrder = 6
  end
  object lbFiles: TListBox
    Left = 334
    Top = 8
    Width = 228
    Height = 378
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 7
    OnClick = lbFilesClick
  end
  object btnLoad: TButton
    Left = 325
    Top = 472
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Load'
    TabOrder = 8
    OnClick = btnLoadClick
  end
  object odLoadFile: TOpenDialog
    Left = 153
    Top = 265
  end
end
