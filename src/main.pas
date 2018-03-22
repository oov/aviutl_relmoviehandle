unit Main;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

interface

uses
  Windows, SysUtils, AviUtl;

type
  { TRelMovieHandle }

  TRelMovieHandle = class
  private
    FEntry: TFilterDLL;
    FExEdit: PFilter;
    FWindow: THandle;
    function GetEntry: PFilterDLL;

    function InitProc(Filter: PFilter): boolean;
    function ExitProc(Filter: PFilter): boolean;
    procedure ReleaseMovieHandle();
  public
    constructor Create();
    destructor Destroy(); override;
    property Entry: PFilterDLL read GetEntry;
  end;

function GetFilterTableList(): PPFilterDLL; stdcall;

var
  RelMovieHandle: TRelMovieHandle;

implementation

uses
  Hook, Ver;

const
  PluginName = '動画ハンドル開放';
  PluginNameANSI = #$93#$AE#$89#$E6#$83#$6E#$83#$93#$83#$68#$83#$8B#$8A#$4A#$95#$FA;
  PluginInfoANSI = PluginNameANSI + ' ' + Version;

const
  BoolConv: array[boolean] of AviUtlBool = (AVIUTL_FALSE, AVIUTL_TRUE);

var
  FilterDLLList: array of PFilterDLL;

function GetFilterTableList(): PPFilterDLL; stdcall;
begin
  Result := @FilterDLLList[0];
end;

function FilterFuncInit(fp: PFilter): AviUtlBool; cdecl;
begin
  Result := BoolConv[RelMovieHandle.InitProc(fp)];
end;

function FilterFuncExit(fp: PFilter): AviUtlBool; cdecl;
begin
  Result := BoolConv[RelMovieHandle.ExitProc(fp)];
end;

function MenuWndProc(hwnd: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT; stdcall;
begin
  case Msg of
    WM_FILTER_COMMAND:
    begin
      case WP of
        1: RelMovieHandle.ReleaseMovieHandle();
      end;
    end;
  end;
  Result := DefWindowProc(hwnd, Msg, WP, LP);
end;

{ TRelMovieHandle }

procedure TRelMovieHandle.ReleaseMovieHandle();
begin
  InitHook(FExEdit^.DLLHInst);
  try
    SetDialogBoxParamAHook(True);
    try
      SetNewValue(0);
      SendMessage(FExEdit^.Hwnd, WM_COMMAND, 1014, 0);
      SetNewValue(GetOldValue());
      SendMessage(FExEdit^.Hwnd, WM_COMMAND, 1014, 0);
    finally
      SetDialogBoxParamAHook(False);
    end;
  finally
    FreeHook();
  end;
end;

function TRelMovieHandle.InitProc(Filter: PFilter): boolean;
type
  ShiftJISString = type ansistring(932);
const
  ReleaseMovieHandleCaption: WideString = '動画ハンドルを開放';
  ExEditNameANSI = #$8a#$67#$92#$a3#$95#$d2#$8f#$57; // '拡張編集'
  ExEditVersion = ' version 0.92 ';
  HWND_MESSAGE = HWND(-3);
var
  i: integer;
  wc: WNDCLASS;
  asi: TSysInfo;
  p: PFilter;
begin
  Result := True;
  FWindow := 0;

  try
    if Filter^.ExFunc^.GetSysInfo(nil, @asi) = AVIUTL_FALSE then
      raise Exception.Create(
        'AviUtl のバージョン情報取得に失敗しました。');
    if asi.Build < 10000 then
      raise Exception.Create('AviUtl version 1.00 以降が必要です。');
    for i := 0 to asi.FilterN - 1 do
    begin
      p := Filter^.ExFunc^.GetFilterP(i);
      if (p = nil) or (p^.Name <> ExEditNameANSI) then
        continue;
      if StrPos(p^.Information, ExEditVersion) = nil then
        raise Exception.Create('拡張編集' + ExEditVersion +
          'が必要です。');
      FExEdit := p;
      break;
    end;
  except
    on E: Exception do
    begin
      MessageBoxW(0, PWideChar('初期化に失敗しました。'#13#10#13#10 +
        WideString(E.Message)),
        PluginName, MB_ICONERROR);
      Exit;
    end;
  end;

  wc.style := 0;
  wc.lpfnWndProc := @MenuWndProc;
  wc.cbClsExtra := 0;
  wc.cbWndExtra := 0;
  wc.hInstance := Filter^.DLLHInst;
  wc.hIcon := 0;
  wc.hCursor := 0;
  wc.hbrBackground := 0;
  wc.lpszMenuName := nil;
  wc.lpszClassName := 'ReleaseMovieHandleMessageWindow';
  Windows.RegisterClass(wc);
  FWindow := CreateWindow('ReleaseMovieHandleMessageWindow', nil,
    WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
    CW_USEDEFAULT, HWND_MESSAGE, 0, Filter^.DLLHInst, nil);
  Filter^.ExFunc^.AddMenuItem(Filter, PChar(ShiftJISString(ReleaseMovieHandleCaption)),
    FWindow, 1, VK_F5, ADD_MENU_ITEM_FLAG_KEY_CTRL);
  Filter^.Hwnd := FWindow;
end;

function TRelMovieHandle.ExitProc(Filter: PFilter): boolean;
begin
  Result := True;
end;

function TRelMovieHandle.GetEntry: PFilterDLL;
begin
  Result := @FEntry;
end;

constructor TRelMovieHandle.Create();
begin
  inherited Create;

  FillChar(FEntry, SizeOf(FEntry), 0);
  FEntry.Flag := FILTER_FLAG_ALWAYS_ACTIVE or FILTER_FLAG_EX_INFORMATION or
    FILTER_FLAG_NO_CONFIG;
  FEntry.Name := PluginNameANSI;
  FEntry.Information := PluginInfoANSI;
end;

destructor TRelMovieHandle.Destroy();
begin
  inherited Destroy;
end;

initialization
  RelMovieHandle := TRelMovieHandle.Create();
  RelMovieHandle.Entry^.FuncInit := @FilterFuncInit;
  RelMovieHandle.Entry^.FuncExit := @FilterFuncExit;

  SetLength(FilterDLLList, 2);
  FilterDLLList[0] := RelMovieHandle.Entry;
  FilterDLLList[1] := nil;


finalization
  RelMovieHandle.Free();

end.
