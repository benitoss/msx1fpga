@echo off

echo Erasing unwanted files
wsl find -type f -size 0 -delete 
wsl find -type d -iname greybox_tmp -exec rm -rf {} \;

echo Cleaning SW
docker run --rm -it -v %cd%:/src fbelavenuto/8bitcompilers make -f Makefile-software clean
IF ERRORLEVEL 1 GOTO error

echo Cleaning Xilinx bitstreams
docker run --rm -it --mac-address 08:00:27:68:c9:35 -e TZ=America/Sao_Paulo -v %cd%:/workdir fbelavenuto/xilinxise make -f Makefile-xilinx clean
IF ERRORLEVEL 1 GOTO error

echo Cleaning Altera bitstreams
docker run --rm -it --mac-address 00:01:02:03:04:05 -e TZ=America/Sao_Paulo -v %cd%:/workdir fbelavenuto/alteraquartus make -f Makefile-altera clean
IF ERRORLEVEL 1 GOTO error

goto ok

:error
echo Ocorreu algum erro!
:ok
echo.
pause
