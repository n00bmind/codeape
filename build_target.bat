@echo off
set MODS_PATH=%DEV_HOME%/bin/jai_modules

jai build_target.jai -import_dir %MODS_PATH% -plug reflector - %* --- import_dir %MODS_PATH%
