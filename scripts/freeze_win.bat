@echo off
setlocal
python -m venv venv
call venv\Scripts\activate
pip install --upgrade pip
pip install -r python\runner\requirements.txt pyinstaller
pyinstaller python\runner\kestrel_runner.py --onefile --name kestrel_runner
copy dist\kestrel_runner.exe plugin\WildlifeAI.lrplugin\bin\win\
python scripts\package_plugin.py
endlocal
