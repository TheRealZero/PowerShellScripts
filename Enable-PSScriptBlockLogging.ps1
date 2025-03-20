function Enable-PSScriptBlockLogging
 {
 # Registry key 
 $basePath = 'HKLM:\Software\Policies\Microsoft\Windows\PowerShell\ScriptBlockLogging' 

# Create the key if it does not exist 
if(-not (Test-Path $basePath)) 

{     

$null = New-Item $basePath -Force     

# Create the correct properties      
New-ItemProperty $basePath -Name "EnableScriptBlockLogging" -PropertyType Dword 
Write-Verbose "Script lock logging enabled"
} 

# These can be enabled (1) or disabled (0) by changing the value 
Set-ItemProperty $basePath -Name "EnableScriptBlockLogging" -Value "1"
 }