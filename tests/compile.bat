SET file_name=hwn_test.map

SET tools_dir=D:/vzhlt_34/

SET hlcsg=hlcsg_x64.exe
SET hlbsp=hlbsp_x64.exe
SET hlvis=hlvis_x64.exe
SET hlrad=hlrad_x64.exe


%tools_dir%/%hlcsg% %file_name% -nowadtextures
%tools_dir%/%hlbsp% %file_name%
%tools_dir%/%hlvis% %file_name% -full
%tools_dir%/%hlrad% %file_name% -extra -dscale 1 -bounce 8 -smooth 180

del /s /q /f *.err
del /s /q /f *.ext
del /s /q /f *.prt
del /s /q /f *.wa_

pause