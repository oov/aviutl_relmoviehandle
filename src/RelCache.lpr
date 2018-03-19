library GCMZDrops;

{$mode objfpc}{$H+}
{$CODEPAGE UTF-8}

uses
  SysUtils,
  AviUtl,
  Main,
  Hook;

exports
  GetFilterTableList;

initialization
  SetMultiByteConversionCodePage(CP_UTF8);
  Randomize();

end.
