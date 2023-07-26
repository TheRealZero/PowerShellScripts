Import-Module Pode
Start-PodeServer -ScriptBlock {

    Add-PodeEndpoint -Address localhost -Port 9999 -Protocol Http

    Add-PodeRoute -Method Get -Path "/api/v1/monitor/:choice" -ScriptBlock {
        InvokeMonitorSourceChange -choice $WebEvent.Parameters['choice']
        Write-PodeJsonResponse -StatusCode 200
    }

}

Function InvokeMonitorSourceChange {
    param(
        [Parameter(Mandatory = $true)]
        [string]$choice
    )
    If ($choice -eq "HDMI1" -or $inputChoice -eq "Desktop") {
        C:\Windows\system32\DisplaySwitch.exe 3
        C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" D6 1
        Start-Sleep -Seconds 2
        C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" 60 17
        Continue
        Write-Output $choice
    }
    ElseIf ($choice -eq "HDMI2" -or $inputChoice -eq "Laptop") {
        C:\Windows\system32\DisplaySwitch.exe 2
        C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" D6 1
        Start-Sleep -Seconds 2
        C:\Users\lucas\Downloads\ControlMyMonitor\ControlMyMonitor.exe /SetValue "2367" 60 18
        Continue
        Write-Output $choice
    }
    Else { Write-Output "Unknown Input Choice $choice" }
}
