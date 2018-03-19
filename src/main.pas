unit Main;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

interface

uses
  Windows, SysUtils, AviUtl;

type
  { TRelCache }

  TRelCache = class
  private
    FEntry: TFilterDLL;
    FExEdit: PFilter;
    FWindow: THandle;
    function GetEntry: PFilterDLL;

    function InitProc(Filter: PFilter): boolean;
    function ExitProc(Filter: PFilter): boolean;
    procedure ReleaseCache();
  public
    constructor Create();
    destructor Destroy(); override;
    property Entry: PFilterDLL read GetEntry;
  end;

function GetFilterTableList(): PPFilterDLL; stdcall;

var
  RelCache: TRelCache;

implementation

uses
  Hook, Ver;

const
  PluginName = '拡張編集キャッシュリリース';
  PluginNameANSI = #$8A#$67#$92#$A3#$95#$D2#$8F#$57#$83#$4C#$83#$83#$83#$62#$83#$56#$83#$85#$83#$8A#$83#$8A#$81#$5B#$83#$58;
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
  Result := BoolConv[RelCache.InitProc(fp)];
end;

function FilterFuncExit(fp: PFilter): AviUtlBool; cdecl;
begin
  Result := BoolConv[RelCache.ExitProc(fp)];
end;

function MenuWndProc(hwnd: HWND; Msg: UINT; WP: WPARAM; LP: LPARAM): LRESULT; stdcall;
begin
  case Msg of
    WM_FILTER_COMMAND:
    begin
      case WP of
        1: RelCache.ReleaseCache();
      end;
    end;
  end;
  Result := DefWindowProc(hwnd, Msg, WP, LP);
end;

{ TRelCache }

procedure TRelCache.ReleaseCache();
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

function TRelCache.InitProc(Filter: PFilter): boolean;
type
  ShiftJISString = type ansistring(932);
const
  ReleaseCacheCaption: WideString = '動画キャッシュを開放';
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
  wc.lpszClassName := 'ExEditReleaseCacheMessageWindow';
  Windows.RegisterClass(wc);
  FWindow := CreateWindow('ExEditReleaseCacheMessageWindow', nil,
    WS_OVERLAPPEDWINDOW, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
    CW_USEDEFAULT, HWND_MESSAGE, 0, Filter^.DLLHInst, nil);
  Filter^.ExFunc^.AddMenuItem(Filter, PChar(ShiftJISString(ReleaseCacheCaption)),
    FWindow, 1, VK_F5, ADD_MENU_ITEM_FLAG_KEY_CTRL);
  Filter^.Hwnd := FWindow;
end;

function TRelCache.ExitProc(Filter: PFilter): boolean;
begin
  Result := True;
end;

function TRelCache.GetEntry: PFilterDLL;
begin
  Result := @FEntry;
end;

constructor TRelCache.Create();
begin
  inherited Create;

  FillChar(FEntry, SizeOf(FEntry), 0);
  FEntry.Flag := FILTER_FLAG_ALWAYS_ACTIVE or FILTER_FLAG_EX_INFORMATION or
    FILTER_FLAG_NO_CONFIG;
  FEntry.Name := PluginNameANSI;
  FEntry.Information := PluginInfoANSI;
end;

destructor TRelCache.Destroy();
begin
  inherited Destroy;
end;

initialization
  RelCache := TRelCache.Create();
  RelCache.Entry^.FuncInit := @FilterFuncInit;
  RelCache.Entry^.FuncExit := @FilterFuncExit;

  SetLength(FilterDLLList, 2);
  FilterDLLList[0] := RelCache.Entry;
  FilterDLLList[1] := nil;


finalization
  RelCache.Free();

end.
