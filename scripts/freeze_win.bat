@echo off
setlocal
python -m venv venv
call venv\Scripts\activate
pip install --upgrade pip
pip install -r python\runner\requirements.txt pyinstaller
pyinstaller python\runner\wai_runner.py --onefile --name wai_runner
copy dist\wai_runner.exe plugin\WildlifeAI.lrplugin\bin\win\
python scripts\package_plugin.py
endlocal
