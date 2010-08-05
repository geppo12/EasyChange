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
    Top = 35
    Width = 320
    Height = 351
    Anchors = [akLeft, akTop, akBottom]
    ColCount = 2
    FixedCols = 0
    FixedRows = 0
    Options = [goFixedVertLine, goFixedHorzLine, goVertLine, goHorzLine, goEditing]
    ScrollBars = ssVertical
    TabOrder = 5
    OnSelectCell = sgPropertySelectCell
    OnSetEditText = sgPropertySetEditText
    ColWidths = (
      78
      73)
  end
  object eFileName: TEdit
    Left = 8
    Top = 8
    Width = 509
    Height = 21
    Anchors = [akLeft, akTop, akRight]
    TabOrder = 0
    ExplicitWidth = 275
  end
  object btnSelect: TButton
    Left = 523
    Top = 8
    Width = 39
    Height = 21
    Anchors = [akTop, akRight]
    Caption = '...'
    TabOrder = 1
    OnClick = btnSelectClick
    ExplicitLeft = 289
  end
  object btnOk: TButton
    Left = 487
    Top = 472
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Process'
    TabOrder = 2
    OnClick = btnOkClick
    ExplicitLeft = 253
  end
  object cbMultiple: TComboBox
    Left = 120
    Top = 209
    Width = 145
    Height = 21
    Style = csDropDownList
    DragMode = dmAutomatic
    TabOrder = 3
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
    TabOrder = 4
    Visible = False
    OnClick = btnPathClick
    ExplicitLeft = 242
  end
  object btnExit: TButton
    Left = 406
    Top = 472
    Width = 75
    Height = 25
    Anchors = [akRight, akBottom]
    Caption = 'Exit'
    TabOrder = 6
    OnClick = btnExitClick
    ExplicitLeft = 172
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
    TabOrder = 7
    ExplicitWidth = 320
  end
  object cbUseProject: TCheckBox
    Left = 8
    Top = 463
    Width = 87
    Height = 17
    Caption = 'Use Project'
    TabOrder = 8
  end
  object lbFiles: TListBox
    Left = 334
    Top = 35
    Width = 228
    Height = 351
    Anchors = [akLeft, akTop, akRight, akBottom]
    ItemHeight = 13
    TabOrder = 9
    OnClick = lbFilesClick
  end
  object odLoadFile: TOpenDialog
    Left = 153
    Top = 265
  end
end
