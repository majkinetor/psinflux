
$module_path = "$Env:ProgramFiles\WindowsPowerShell\Modules\psinflux"
mkdir $module_path -ea 0
cp $PSScriptRoot\* $module_path


if (!(gcm fzf.exe -ea 0)) { Write-Host "Please install fzf or put in on the PATH: cinst fzf" }


