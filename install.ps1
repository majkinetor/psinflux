
$module_path = "$Env:ProgramFiles\WindowsPowerShell\Modules\psinflux"
mkdir $module_path -ea 0
cp $PSScriptRoot\* $module_path



