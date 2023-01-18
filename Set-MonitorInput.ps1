param(
    $inputChoice
)
Function Set-HDMI2{# Laptops

    C:\Windows\system32\DisplaySwitch.exe 2
    C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" D6 1
    Start-Sleep -Seconds 2
    C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" 60 18
}

Function Set-HDMI1{# Desktop
    C:\Windows\system32\DisplaySwitch.exe 3
    C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" D6 1
    Start-Sleep -Seconds 2
    C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" 60 17
}

Function Set-VGA{
    C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" 60 1
}
Function Get-CurrentInput{
    $cv = C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /GetValue "2367" 60
    if($cv -eq 18){
        Write-Output "HDMI2"
    }
    elseif($cv -eq 17){
        Write-Output "HDMI1"
    }
    elseif($cv -eq 1){
        Write-Output "VGA"
    }
    else{
        Write-Output "Unknown"
    }
}

if ($inputChoice -eq "HDMI2" -OR $inputChoice -eq "Laptop" ){
    Set-HDMI2
}
elseif ($inputChoice -eq "HDMI1" -OR $inputChoice -eq "Desktop"){
    Set-HDMI1
}
elseif ($inputChoice -eq "VGA"){
    Set-VGA
}
else {
    Get-CurrentInput
}

<# AOCc:\g
Monitor Device Name: "\\.\DISPLAY2\Monitor0"
Monitor Name: "2367"
Serial Number: "BHKD99A002849"
Adapter Name: "NVIDIA GeForce GTX 770"
Monitor ID: "MONITOR\AOC2367\{4d36e96e-e325-11ce-bfc1-08002be10318}\0012"

ViewSonic
Monitor Device Name: "\\.\DISPLAY1\Monitor0"
Monitor Name: "VG2228 SERIES"
Serial Number: "STB124240120"
Adapter Name: "NVIDIA GeForce GTX 770"
Monitor ID: "MONITOR\VSCEE29\{4d36e96e-e325-11ce-bfc1-08002be10318}\0002"
 #>