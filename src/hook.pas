unit Hook;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

interface

procedure InitHook(module: THandle);
procedure SetDialogBoxParamAHook(const b: boolean);
procedure SetNewValue(n: integer);
function GetOldValue(): integer;
procedure FreeHook();

implementation

uses
  Windows;

type
  LPDIALOGBOXPARAMA = function(hInstance: HINST; lpTemplateName: LPCSTR;
    hWndParent: HWND; lpDialogFunc: DLGPROC; dwInitParam: LPARAM): longint; stdcall;

  PImageImportByName = ^TImageImportByName;

  _IMAGE_IMPORT_BY_NAME = packed record
    HInst: word;
    Name: byte;
  end;
  TImageImportByName = _IMAGE_IMPORT_BY_NAME;

  _IMAGE_THUNK_DATA = packed record
    case integer of
      0: (ForwarderString: PByte);
      1: (thFunction: PDWORD);
      2: (Ordinal: DWORD);
      3: (AddressOfData: PImageImportByName);
  end;
  TImageThunkData = _IMAGE_THUNK_DATA;
  IMAGE_THUNK_DATA = _IMAGE_THUNK_DATA;
  PImageThunkData = ^TImageThunkData;

  TCharcteristics = record
    case integer of
      0: (Characteristics: DWORD);
      1: (OriginalFirstThunk: PImageThunkData);
  end;

  PImageImportDescriptor = ^TImageImportDescriptor;

  _IMAGE_IMPORT_DESCRIPTOR = packed record
    c: TCharcteristics;
    TimeDateStamp: DWord;
    ForwarderChain: DWORD;
    Name: DWORD;
    FirstThunk: PImageThunkData;
  end;
  TImageImportDescriptor = _IMAGE_IMPORT_DESCRIPTOR;
  IMAGE_IMPORT_DESCRIPTOR = _IMAGE_IMPORT_DESCRIPTOR;

  TAPIHookEntry = packed record
    ProcName: PChar;
    Module: THandle;
    OriginalProc: Pointer;
    HookProc: Pointer;
  end;

var
  HookEntries: array of TAPIHookEntry;
  TargetModule: THandle;

  pDialogBoxParamA: LPDIALOGBOXPARAMA;
  pDlgProc: DLGPROC;

  UseDialogBoxParamAHook: boolean;
  NewValue, OldValue: integer;

procedure SetDialogBoxParamAHook(const b: boolean);
begin
  UseDialogBoxParamAHook := b;
end;

procedure SetNewValue(n: integer);
begin
  NewValue := n;
end;

function GetOldValue(): integer;
begin
  Result := OldValue;
end;

function MyDlgProc(hwndDlg: HWND; uMsg: UINT; wParam: WPARAM;
  lParam: LPARAM): LRESULT; stdcall;
const
  NumOfHandleEdit = 173;
var
  d: WINBOOL;
begin
  Result := pDlgProc(hwndDlg, uMsg, wParam, lParam);
  if uMsg = WM_INITDIALOG then
  begin
    OldValue := GetDlgItemInt(hwndDlg, NumOfHandleEdit, d, False);
    SetDlgItemInt(hwndDlg, NumOfHandleEdit, NewValue, True);
    SendMessage(hwndDlg, WM_COMMAND, MAKELONG(idOk, BN_CLICKED),
      GetDlgItem(hwndDlg, idOk));
  end;
end;

function MyDialogBoxParamA(hInstance: HINST; lpTemplateName: LPCSTR;
  hWndParent: HWND; lpDialogFunc: DLGPROC; dwInitParam: LPARAM): longint; stdcall;
begin
  if (not UseDialogBoxParamAHook) or (lpTemplateName <> 'ENV_CONFIG') then
  begin
    Result := pDialogBoxParamA(hInstance, lpTemplateName, hWndParent,
      lpDialogFunc, dwInitParam);
    Exit;
  end;

  pDlgProc := lpDialogFunc;
  Result := pDialogBoxParamA(hInstance, lpTemplateName, hWndParent,
    @MyDlgProc, dwInitParam);
end;

procedure Hook(hModule: THandle; Install: boolean);
var
  i: integer;

  DOSHeader: PImageDosHeader;
  NTHeader: PImageNtHeaders;
  ImageDataDir: PImageDataDirectory;
  PImports: PImageImportDescriptor;
  OldProtect: DWORD;
  PRVA_Import: PImageThunkData;
begin
  DOSHeader := PImageDosHeader(hModule);
  if DOSHeader^.e_magic <> IMAGE_DOS_SIGNATURE then
    Exit;

  NTHeader := PImageNtHeaders(PtrUInt(DOSHeader) + PtrUInt(DOSHeader^._lfanew));
  if NTHeader^.Signature <> IMAGE_NT_SIGNATURE then
    Exit;

  if NTHeader^.OptionalHeader.NumberOfRvaAndSizes <= IMAGE_DIRECTORY_ENTRY_IMPORT then
    Exit;

  ImageDataDir := @NTHeader^.OptionalHeader.DataDirectory[IMAGE_DIRECTORY_ENTRY_IMPORT];
  if ImageDataDir^.VirtualAddress = 0 then
    Exit;

  PImports := PImageImportDescriptor(PtrUInt(hModule) +
    PtrUInt(ImageDataDir^.VirtualAddress));
  if PImports = Pointer(NTHeader) then
    Exit;

  while PImports^.Name <> 0 do
  begin
    PRVA_Import := PImageThunkData(PtrUInt(PImports^.FirstThunk) + PtrUInt(hModule));
    while PRVA_Import^.thFunction <> nil do
    begin
      if Install then
        for i := 0 to Length(HookEntries) - 1 do
        begin
          if PRVA_Import^.thFunction = HookEntries[i].OriginalProc then
          begin
            VirtualProtect(PRVA_Import, sizeof(Pointer), PAGE_EXECUTE_READWRITE,
              OldProtect);
            PRVA_Import^.thFunction := HookEntries[i].HookProc;
            VirtualProtect(PRVA_Import, sizeof(Pointer), OldProtect, OldProtect);
            break;
          end;
        end
      else
        for i := 0 to Length(HookEntries) - 1 do
        begin
          if PRVA_Import^.thFunction = HookEntries[i].HookProc then
          begin
            VirtualProtect(PRVA_Import, sizeof(Pointer), PAGE_EXECUTE_READWRITE,
              OldProtect);
            PRVA_Import^.thFunction := HookEntries[i].OriginalProc;
            VirtualProtect(PRVA_Import, sizeof(Pointer), OldProtect, OldProtect);
            break;
          end;
        end;
      Inc(PRVA_Import);
    end;
    Inc(PImports);
  end;
end;

procedure InitHook(module: THandle);
var
  hUSER32DLL: THandle;
begin
  hUSER32DLL := GetModuleHandleW(user32);

  SetLength(HookEntries, 1);
  pDialogBoxParamA := LPDIALOGBOXPARAMA(GetProcAddress(hUSER32DLL,
    'DialogBoxParamA'));
  with HookEntries[0] do
  begin
    ProcName := 'DialogBoxParamA';
    Module := hUSER32DLL;
    OriginalProc := pDialogBoxParamA;
    HookProc := @MyDialogBoxParamA;
  end;

  OldValue := 0;
  NewValue := 0;
  UseDialogBoxParamAHook := False;
  TargetModule := module;
  Hook(TargetModule, True);
end;

procedure FreeHook();
begin
  Hook(TargetModule, False);
end;

end.
