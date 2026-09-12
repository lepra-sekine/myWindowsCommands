@echo off
setlocal enabledelayedexpansion

rem 第一引数は幅または高さを指定します。
rem 第二引数はモードです。省略 / w / r / wr の組み合わせを受け取ります。
rem 省略 : 4:3 のアス比で、入力値を幅として見て高さを出力します。
rem w    : 16:9 のアス比で、入力値を幅として見て高さを出力します。
rem r    : 入力値を高さとして見て幅を出力します。
rem wr   : 16:9 のアス比で、入力値を高さとして見て幅を出力します。

if "%~1"=="" (
    echo Error: First argument is required
    exit /b 1
)

rem 入力値とモードを変数に保存
set "num=%~1"
set "mode=%~2"

rem 既定のアス比は 4:3
set "ratioW=4"
set "ratioH=3"

set "hasW=0"
set "hasR=0"

rem モード文字列に w が含まれていれば 16:9 に切り替える
if not "%mode%"=="" (
    echo %mode% | findstr /i "w" >nul && set "hasW=1"
    echo %mode% | findstr /i "r" >nul && set "hasR=1"
)

if "%hasW%"=="1" (
    set "ratioW=16"
    set "ratioH=9"
)

rem r が付いている場合は、入力値を高さとして扱う
rem その場合は、幅 = 高さ * ratioW / ratioH
rem r が付いていない場合は、入力値を幅として扱う
rem その場合は、高さ = 幅 * ratioH / ratioW
if "%hasR%"=="1" (
    set /a result=num * ratioW / ratioH
) else (
    set /a result=num * ratioH / ratioW
)

echo !result!
endlocal
