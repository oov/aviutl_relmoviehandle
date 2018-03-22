#!/bin/bash

# copy readme
sed 's/\r$//' README.md | sed 's/$/\r/' > bin/RelMovieHandle.txt

# update version string
VERSION='v1.0'
GITHASH=`git rev-parse --short HEAD`
cat << EOS | sed 's/\r$//' | sed 's/$/\r/' > 'src/ver.pas'
unit Ver;

{\$mode objfpc}{\$H+}
{\$CODEPAGE UTF-8}

interface

const
  Version = '$VERSION ( $GITHASH )';

implementation

end.
EOS

# build lazarus project
cmd.exe /c C:/lazarus/lazbuild.exe --build-all src/RelMovieHandle.lpi

# install
# cp bin/*.auf aviutl/
