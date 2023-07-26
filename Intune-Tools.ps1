Function Get-GraphAuthToken {
    $token = ((Invoke-MgGraphRequest -URI "/beta/me" -OutputType HttpResponseMessage).RequestMessage.Headers.Authorization).ToString() # | ConvertTo-SecureString -AsPlainText -Force
    $token
}

Function Get-NextLink {
    param(
        [Parameter(valueFromPipeline = $true)]
        $data
    )
    $data.value
    If ([bool]($data.'@odata.nextlink')) {
        $resp = Invoke-MGGraphRequest -URI $($data.'@odata.nextlink')-OutputType HashTable
        Get-NextLink -data $resp
        
    }
    
}
Function New-ObjectFromJsonSchema {
    param(
        $jsonData
    )

    $objects = foreach ($row in $jsonData.Values) {
        $object = New-Object -TypeName PSObject
        for ($i = 0; $i -lt $jsonData.Schema.Count; $i++) {
            $columnName = $jsonData.Schema[$i].Column
            $propertyType = $jsonData.Schema[$i].PropertyType
            $value = $row[$i]
            Set-Variable -Name $columnName -Value $value
            Add-Member -InputObject $object -MemberType NoteProperty -Name $columnName -Value $value
        }
        $object
    }
    Write-Output $objects
}

Function Get-AutoPilotProfile {
    $resp = Invoke-MGGraphRequest -URI "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles?expand=assignments" -OutputType PSObject | Get-NextLink
    Write-Output $resp
}

Function Get-AutoPilotDevice {
    
    $resp = Invoke-MgGraphRequest -URI "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities" -OutputType Hashtable | Get-NextLink
    Write-Output $resp

}
Function Get-AutoPilotTags {
    (Get-MgDeviceManagementWindowAutopilotDeviceIdentity -All).grouptag | select-object -Unique
}

Function Get-ESPProfiles {
    $resp = Invoke-MGGraphRequest -URI "https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations?expand=assignments&filter=deviceEnrollmentConfigurationType%20eq%20%27Windows10EnrollmentCompletionPageConfiguration%27" | Get-NextLink
    $resp
}

Function Get-AssignedGroupsAutoPilotProfile {
    param(
        $profileId,
        $profileName
    )
    $autoPilotProfiles = Get-AutoPilotProfile
    If ($profileId) {
        $propertyName = "id"
        $propertyValue = "$profileId"

    }
    Else {
        $propertyName = "displayName"
        $propertyValue = "$profileName"
    }
    ($autoPilotProfiles.value |
    Where-Object -property $propertyName -eq $propertyValue).assignments |
    Foreach-Object { If ($null -ne $_) {
            Get-MGGroup -GroupId $(
                            ($_.id).Replace("$($_.sourceid)_", "")).substring(0, 36)
        
        }#foreach
    }#if
}

Function Get-AllAppsForGroup {
    param($groupId)
    Get-MgDeviceAppManagementMobileApp -all -ExpandProperty assignments |
    Where-Object { $_.assignments.target.additionalproperties.groupId -Contains $groupId
    }
}

Function Get-AllConfigProfiles {
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    $groupPolicyConfigurations = Get-MgDeviceManagementGroupPolicyConfiguration -all -ExpandProperty assignments |
    Where-Object { $_.assignments.target.additionalproperties.groupId -Contains $assignedGroupId
    }

    $deviceConfigurations = Get-MgDeviceManagementDeviceConfiguration -all -ExpandProperty assignments |
    Where-Object { $_.assignments.target.AdditionalProperties.groupId -Contains $assignedGroupId
    }

    $configurationPolicies = Get-MgDeviceManagementConfigurationPolicy -all -ExpandProperty assignments |
    Where-Object { $_.assignments.target.AdditionalProperties.groupId -Contains $assignedGroupId
    }

    #$output = @($groupPolicyConfigurations,$deviceConfigurations,$configurationPolicies)

    
    $output = new-object psobject
    Add-Member -InputObject $output -NotePropertyMembers @{
        "groupPolicyConfigurations" = $groupPolicyConfigurations
        "deviceConfigurations"      = $deviceConfigurations
        "configurationPolicies"     = $configurationPolicies

    }
    $output
}
Function Get-AllScripts {
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    Get-MgDeviceManagementScript -ExpandProperty assignments -All |
    Where-Object { $_.assignments.target.AdditionalProperties.groupId -Contains $assignedGroupId
    }
}

Function Get-AllCompliancePolicies {
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    Get-MgDeviceManagementDeviceCompliancePolicy -ExpandProperty assignments -All|
    Where-Object { $_.assignments.target.AdditionalProperties.groupId -Contains $assignedGroupId }
}
Function Get-AutoPilotProfileFromGroup{
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    Get-MgDeviceManagementWindowAutopilotDeploymentProfile -expand assignments -All|Where-Object {$_.Assignments.Target.AdditionalProperties.groupId -contains $assignedGroupId }

}
Function Get-EnrollmentConfigurationFromGroup{
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    Get-MgDeviceManagementdeviceEnrollmentConfiguration -expand assignments -All|Where-Object {$_.Assignments.Target.AdditionalProperties.groupId -contains $assignedGroupId }
}

Function Get-ProactiveRemediationScriptsFromGroup{
    param(
        [Parameter(Mandatory)]
        $assignedGroupId
    )
    Get-MgDeviceManagementDeviceHealthScript -All -ExpandProperty Assignments |Where-Object {$_.assignments.target.additionalproperties.groupId -eq $assignedGroupId}
}


#region:reports

#-------
#Get Setting Details per policy
Function Get-ConfigurationSettingReport {
    param(
        $deviceId,
        $PolicyId,
        $userId,
        $outFilePath = ""
    )
    #Settings Catalog
    $params = @{
    
        Skip    = 0
        Top     = 50
        Filter  = "(PolicyId eq '$PolicyId') and (DeviceId eq '$deviceId') and (UserId eq '$userId')"
        OrderBy = @(
        )
        
    }
    $outfile = "$outFilePath\ReportConfigurationSettingReport--$(get-Date -format FileDateTimeUniversal).json"
    Get-MgDeviceManagementReportConfigurationSettingReport -BodyParameter $params -OutFile $outfile
    $json = Get-Content -Path $outfile | ConvertFrom-Json
    $ReportConfigurationSettingReport = New-ObjectFromJsonSchema -jsonData $json
    While ($json.TotalRowCount -gt ($params.skip + $params.top)) {
        $params.skip = $params.skip + $params.top
        $outfile = "$($outfile.Substring(0,$($outfile).length -5))--Skip$($params.skip).json"

        Get-MgDeviceManagementReportConfigurationSettingReport -BodyParameter $params -OutFile $outfile
        $json = Get-Content -Path $outfile | ConvertFrom-Json
        $ReportConfigurationSettingReport += New-ObjectFromJsonSchema -jsonData $json
    }
    $ReportConfigurationSettingReport
}

Function Get-ConfigurationSettingNonComplianceReport {
    param(
        $deviceId,
        $PolicyId,
        $userId,
        $outFilePath 
    )
    #Device Configuration
    $params = @{
    
        Skip    = 0
        Top     = 50
        Filter  = "(PolicyId eq '$PolicyId') and (DeviceId eq '$deviceId') and (UserId eq '$userId')"
        OrderBy = @(
        )
        
    }
    $outfile = "$outFilePath\ReportConfigurationSettingNonComplianceReport--$(get-Date -format FileDateTimeUniversal).json"

    Get-MgDeviceManagementReportConfigurationSettingNonComplianceReport -BodyParameter $params -OutFile $outfile

    $json = Get-Content -Path $outfile | ConvertFrom-Json
    $ReportConfigurationSettingNonComplianceReport = New-ObjectFromJsonSchema -jsonData $json

    While ($json.TotalRowCount -gt ($params.skip + $params.top)) {

        $params.skip = $params.skip + $params.top
        $outfile = "$($outfile.Substring(0,$($outfile).length -5))--Skip$($params.skip).json"

        Get-MgDeviceManagementReportConfigurationSettingNonComplianceReport -BodyParameter $params -OutFile $outfile

        $json = Get-Content -Path $outfile | ConvertFrom-Json
        $ReportConfigurationSettingNonComplianceReport += New-ObjectFromJsonSchema -jsonData $json
    }
    $ReportConfigurationSettingNonComplianceReport
}

Function Get-GroupPolicySettingDeviceSettingReport {
    param(
        $deviceId,    
        $PolicyId,    
        $userId,      
        $outFilePath
    )
    $params = @{
    
        Skip    = 0
        Top     = 50
        Filter  = "(PolicyId eq '$PolicyId') and (DeviceId eq '$deviceId') and (UserId eq '$userId')"
        OrderBy = @(
        )
    }
    $outfile = "$outFilePath\ReportGroupPolicySettingDeviceSettingReport--$(get-Date -format FileDateTimeUniversal).json"

    Get-MgDeviceManagementReportGroupPolicySettingDeviceSettingReport -BodyParameter $params -OutFile $outfile
    
    $json = Get-Content -Path $outfile | ConvertFrom-Json
    $ReportGroupPolicySettingDeviceSettingReport = New-ObjectFromJsonSchema -jsonData $json

    While ($json.TotalRowCount -gt ($params.skip + $params.top)) {

        $params.skip = $params.skip + $params.top
        $outfile = "$($outfile.Substring(0,$($outfile).length -5))--Skip$($params.skip).json"

        Get-MgDeviceManagementReportGroupPolicySettingDeviceSettingReport -BodyParameter $params -OutFile $outfile

        $json = Get-Content -Path $outfile | ConvertFrom-Json
        $ReportGroupPolicySettingDeviceSettingReport += New-ObjectFromJsonSchema -jsonData $json

    }
    $ReportGroupPolicySettingDeviceSettingReport
}


Function Get-ConfigurationPolicyReportForDevice {
    param(
        $deviceId = '0f8ca11c-3a76-4024-a550-86c29a612447',
        $outFolder = "C:\git\3MMD-Conversion\Reporting"
    )
    $params = @{
    
        Filter  = "((PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceConfiguration') or (PolicyBaseTypeName eq 'DeviceManagementConfigurationPolicy') or (PolicyBaseTypeName eq 'DeviceConfigurationAdmxPolicy') or (PolicyBaseTypeName eq 'Microsoft.Management.Services.Api.DeviceManagementIntent')) and (IntuneDeviceId eq '$deviceId')"
        Skip    = 0
        Top     = 50
        OrderBy = @(
            "PolicyName"
        )
    }
    $outfile = "$outFilePath\ReportConfigurationPolicyReportForDevice--$deviceId--$(get-Date -format FileDateTimeUniversal).json"
    
    Get-MgDeviceManagementReportConfigurationPolicyReportForDevice -BodyParameter $params -OutFile $outfile
    $json = Get-Content -Path $outfile | ConvertFrom-Json
    $ReportConfigurationPolicyReportForDevice = New-ObjectFromJsonSchema -jsonData $json

    While ($json.TotalRowCount -gt ($params.skip + $params.top)) {
        $params.skip = $params.skip + $params.top
        $outfile = "$($outfile.Substring(0,$($outfile).length -5))--Skip$($params.skip).json"
        Get-MgDeviceManagementReportConfigurationPolicyReportForDevice -BodyParameter $params -OutFile $outfile
        $json = Get-Content -Path $outfile | ConvertFrom-Json
        $ReportConfigurationPolicyReportForDevice += New-ObjectFromJsonSchema -jsonData $json
    }
    $ReportConfigurationPolicyReportForDevice
}
#endregion:reports

#-------
Function Get-ProfilesFromGroupSettingsForDevice {
    param(
        [Parameter(Mandatory)]
        $assignedGroupId,
        [Parameter(Mandatory)]
        $deviceId,
        [Parameter(Mandatory)]
        $userId
    )

    $profiles = Get-AllConfigProfiles -assignedGroupId $assignedGroupId
    $policyReport = Get-ConfigurationPolicyReportForDevice -deviceId $deviceId

    $deviceConfigurationSettingNonComplianceReport = Foreach ($entry in $($profiles.deviceConfigurations)) { Get-ConfigurationSettingNonComplianceReport -PolicyId $entry.id -deviceId $deviceId -userId $userId }
    $deviceConfigurationSettingReport = Foreach ($entry in $($profiles.configurationPolicies)) { Get-ConfigurationSettingReport -PolicyId $entry.PolicyId -deviceId $deviceId -userId $userId }
    $deviceGroupPolicySettingDeviceSettingReport = Foreach ($entry in $($profiles.groupPolicyConfigurations)) { Get-GroupPolicySettingDeviceSettingReport -PolicyId $entry.Id-deviceId $deviceId -userId $userId }

    $deviceConfigurationSettingReport               | Export-CSV -Path .\Reporting\ReportConfigurationSettingReport--$deviceId--$(get-Date -format FileDateTimeUniversal).csv  -NoTypeInformation
    $deviceConfigurationSettingNonComplianceReport  | Export-CSV -Path .\Reporting\ReportConfigurationSettingNonComplianceReport--$deviceId--$(get-Date -format FileDateTimeUniversal).csv -NoTypeInformation
    $deviceGroupPolicySettingDeviceSettingReport    | Export-CSV -Path .\Reporting\ReportGroupPolicySettingDeviceSettingReport--$deviceId--$(get-Date -format FileDateTimeUniversal).csv -NoTypeInformation
    $policyReport                                   | Export-CSV -Path .\Reporting\ReportConfigurationPolicyReportForDevice--$(get-Date -format FileDateTimeUniversal).csv -NoTypeInformation
}

Function Update-ConfigurationPolicy {

    param(
        [Parameter(Mandatory)]
        $policyId = '',
        [Parameter(Mandatory)]
        $targetGroupId = ''
    )
    $originalAssignments = Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assignments" | Get-NextLink
    $dateFileUniversal = Get-Date -format FileDateTimeUniversal
    
    If (!((($originalAssignments.id) -contains "$($policyId)_$($targetGroupId)"))) {
        $originalAssignments | Convertto-JSON | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--OriginalAssignments--$dateFileUniversal.json"
        Write-host "Assigning $targetGroupId to $policyId"
        $newAssignmentGroupTarget = '{
            "@odata.type":  "#microsoft.graph.groupAssignmentTarget",
            "groupId":  "",
            "deviceAndAppManagementAssignmentFilterType":  "none",
            "deviceAndAppManagementAssignmentFilterId":  null
        }'| convertfrom-json
        $newAssignmentGroupTarget.groupId = $targetGroupId
        $newAssignmentGroupTargetHashtable = @{}
        foreach ( $property in $($newAssignmentGroupTarget.psobject.properties.name)) {
            $newAssignmentGroupTargetHashtable[$property] = $newAssignmentGroupTarget.$property
        }
        
        

        $newAssignmentGroup = new-object -TypeName hashtable
        $newAssignmentGroup["target"] = $newAssignmentGroupTargetHashtable
        
        $combinedAssignments = @()
        $originalAssignments | foreach { $combinedAssignments += @{id = $_.id; target = $_.target } }
        $newAssignmentGroup | foreach { $combinedAssignments += @{target = $_.target } }
        $configurationPolicyBody = @{"assignments" = @($combinedAssignments) } | convertto-json -Depth 10
        (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assign" -method post -body $configurationPolicyBody)

        $updatedAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/$policyId/assignments").value
        $updatedAssignments | Convertto-JSON                        | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--UpdatedAssignments--$dateFileUniversal.json" -Encoding utf8

        "Combined <-> Original"                                     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $originalAssignments                 | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Combined <-> Updated"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $updatedAssignments                  | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Updated <-> Original"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $updatedAssignments $originalAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
    }
}

Function Update-DeviceConfigurations {
    param(
        [Parameter(Mandatory)]
        $policyId = '',
        [Parameter(Mandatory)]
        $targetGroupId = ''
    )
    $originalAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$policyId/assignments?select=id,target").value
    $dateFileUniversal = Get-Date -format FileDateTimeUniversal
    If (!(($originalAssignments.id) -contains "$($policyId)_$($targetGroupId)")) {
        $originalAssignments | Convertto-JSON | Out-File -FilePath "\temp\Update-DeviceConfiguration--OriginalAssignments--$dateFileUniversal.json"
        Write-host "Assigning $targetGroupId to $policyId"
        $combinedAssignments = $originalAssignments + @{
            target = @{
                '@odata.type'                                = '#microsoft.graph.groupAssignmentTarget'
                "groupId"                                    = $targetGroupId
                "deviceAndAppManagementAssignmentFilterType" = "none"
                "deviceAndAppManagementAssignmentFilterId"   = $null
            }
        }
        

        
        
        $body = @{assignments = $combinedAssignments } | convertto-json -depth 3
        $body
        Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceconfigurations/$($policyId)/assign" -method post -Body $body -ErrorAction Stop
        
        $updatedAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$policyId/assignments").value
        $updatedAssignments | Convertto-JSON                        | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--UpdatedAssignments--$dateFileUniversal.json" -Encoding utf8

        "Combined <-> Original"                                     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $originalAssignments    | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Combined <-> Updated"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $updatedAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Updated <-> Original"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $updatedAssignments $originalAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
    }
}

Function Update-groupPolicyConfigurations {
    param(
        [Parameter(Mandatory)]
        $policyId = '',
        [Parameter(Mandatory)]
        $targetGroupId = ''
    )
    $originalAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$policyId/assignments").value
    $dateFileUniversal = Get-Date -format FileDateTimeUniversal
    
    If (!(($originalAssignments.id) -contains "$($policyId)_$($targetGroupId)")) {
        $originalAssignments | Convertto-JSON | Out-File -FilePath "\temp\Update-GroupPolicyConfiguration--$policyId--OriginalAssignments--$dateFileUniversal.json"
        Write-host "Assigning $targetGroupId to $policyId"
        $originalAssignments |
        Foreach {
            $_.Remove('lastModifiedDateTime')
        }
        $combinedAssignments = $originalAssignments + @{
            target = @{
                '@odata.type'                                = '#microsoft.graph.groupAssignmentTarget'
                "groupId"                                    = $targetGroupId
                "deviceAndAppManagementAssignmentFilterType" = "none"
                "deviceAndAppManagementAssignmentFilterId"   = $null
            }
        }
        
        $body = @{assignments = $combinedAssignments } | convertto-json -depth 3
        
        Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policyId)/assign" -method post -Body $body -ErrorAction Stop

        $updatedAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/groupPolicyConfigurations/$($policyId)/assignments").value
        $updatedAssignments | Convertto-JSON                        | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--UpdatedAssignments--$dateFileUniversal.json" -Encoding utf8

        "Combined <-> Original"                                     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $originalAssignments    | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Combined <-> Updated"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $updatedAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Updated <-> Original"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $updatedAssignments $originalAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
    }   
}
Function Update-CompliancePolicy {
    param(
        [Parameter(Mandatory)]
        $policyId = '',
        [Parameter(Mandatory)]
        $targetGroupId = ''
    )
    $originalAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$policyId/assignments").value
    $dateFileUniversal = Get-Date -format FileDateTimeUniversal
    
    If (!(($originalAssignments.id) -contains "$($policyId)_$($targetGroupId)")) {
        $originalAssignments | Convertto-JSON | Out-File -FilePath "\temp\Update-GroupPolicyConfiguration--OriginalAssignments--$dateFileUniversal.json"
        Write-host "Assigning $targetGroupId to $policyId"

        $combinedAssignments = $originalAssignments + @{
            target = @{
                '@odata.type'                                = '#microsoft.graph.groupAssignmentTarget'
                "groupId"                                    = $targetGroupId
                "deviceAndAppManagementAssignmentFilterType" = "none"
                "deviceAndAppManagementAssignmentFilterId"   = $null
            }
        }
        
        $body = @{assignments = $combinedAssignments } | convertto-json -depth 3

        Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$($policyId)/assign" -method post -Body $body -ErrorAction Stop

        
        $updatedAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/$policyId/assignments").value
        $updatedAssignments | Convertto-JSON                        | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--UpdatedAssignments--$dateFileUniversal.json" -Encoding utf8

        "Combined <-> Original"                                     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $originalAssignments    | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Combined <-> Updated"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $updatedAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        "Updated <-> Original"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $updatedAssignments $originalAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$policyId--Comparisons--$dateFileUniversal.txt"
    }   
    <# 
    {"assignments":[{"target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":"f73df3ef-f6de-4a94-a395-c81dfdf122e8","deviceAndAppManagementAssignmentFilterId":"d46ca81c-d103-4955-a98c-803e9c9d458f","deviceAndAppManagementAssignmentFilterType":"exclude"}},{"id":"df39a699-675e-4605-97b7-1300e523ac23_d7a9271e-785f-44fa-9f35-4fb09527b17c","target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":"d7a9271e-785f-44fa-9f35-4fb09527b17c"}},{"id":"df39a699-675e-4605-97b7-1300e523ac23_3d9f17a3-6ef2-4588-b726-c054f95963bd","target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":"3d9f17a3-6ef2-4588-b726-c054f95963bd"}},{"id":"df39a699-675e-4605-97b7-1300e523ac23_dc1191eb-c120-470c-bcbf-d1d3a3eb123b","target":{"@odata.type":"#microsoft.graph.groupAssignmentTarget","groupId":"dc1191eb-c120-470c-bcbf-d1d3a3eb123b"}}]}
 #>

}
Function Update-Apps {
    param(
        [Parameter(Mandatory)]
        $appId = '',
        [Parameter(Mandatory)]
        $targetGroupId = '',
        [Parameter(Mandatory)]
        $appType = ''
    )
    $dateFileUniversal = Get-Date -format FileDateTimeUniversal
   
    $originalAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$appId/assignments").value

    
    If ($targetGroupId -notin ($originalAssignments.id -split "_")) {
        $originalAssignments | Convertto-JSON | Out-File -FilePath "\temp\Update-Apps--$appId--OriginalAssignments--$dateFileUniversal.json"
        Write-host "Assigning $targetGroupId to $appId"
        $appAssignmentSettingType = Switch ($apptype)
        {
            "#microsoft.graph.androidManagedStoreApp"            {"#microsoft.graph.androidManagedStoreAppAssignmentSettings"}
            "#microsoft.graph.iosLobApp"                         {"#microsoft.graph.iosLobAppAssignmentSettings"}
            "#microsoft.graph.iosStoreApp"                       {"#microsoft.graph.iosStoreAppAssignmentSettings"}
            "#microsoft.graph.iosVppApp"                         {"#microsoft.graph.iosVppAppAssignmentSettings"}
            "#microsoft.graph.macOsLobApp"                       {"#microsoft.graph.macOsLobAppAssignmentSettings"}
            "#microsoft.graph.macOsVppApp"                       {"#microsoft.graph.macOsVppAppAssignmentSettings"}
            "#microsoft.graph.microsoftStoreForBusinessApp"      {"#microsoft.graph.microsoftStoreForBusinessAppAssignmentSettings"}
            "#microsoft.graph.win32LobApp"                       {"#microsoft.graph.win32LobAppAssignmentSettings"}
            "#microsoft.graph.windowsAppXApp"                    {"#microsoft.graph.windowsAppXAppAssignmentSettings"}
            "#microsoft.graph.windowsUniversalAppXApp"           {"#microsoft.graph.windowsUniversalAppXAppAssignmentSettings"}
            "#microsoft.graph.winGetApp"                         {"#microsoft.graph.winGetAppAssignmentSettings"}
        
        }
        $settings = @{
            "installTimeSettings"          = $null
            "@odata.type"                  = $appAssignmentSettingType
            "restartSettings"              = $null
            "deliveryOptimizationPriority" = "notConfigured"
            "notifications"                = "showReboot"
        }
        IF($appType -eq "#microsoft.graph.winGetApp"){$settings.Remove("deliveryOptimizationPriority")}

        $combinedAssignments = $originalAssignments + @{
            target   = @{
                '@odata.type'                                = '#microsoft.graph.groupAssignmentTarget'
                "groupId"                                    = $targetGroupId
                "deviceAndAppManagementAssignmentFilterType" = "none"
                "deviceAndAppManagementAssignmentFilterId"   = $null
            }
            intent   = "required"
            settings = $settings

        }
        
        $body = @{mobileAppAssignments = $combinedAssignments } | convertto-json -depth 3
        

        Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($appId)/assign" -method post -Body $body -ErrorAction Stop

        $updatedAssignments = (Invoke-MGGraphRequest -uri "https://graph.microsoft.com/beta/deviceAppManagement/mobileApps/$($appId)/assignments").value


        $updatedAssignments | Convertto-JSON                        | Out-File -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--UpdatedAssignments--$dateFileUniversal.json" -Encoding utf8
        "Combined <-> Original"                                     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $originalAssignments    | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
        "Combined <-> Updated"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $combinedAssignments $updatedAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
        "Updated <-> Original"                                      | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
        Compare-Object $updatedAssignments $originalAssignments     | Out-File -Append -FilePath "\temp\$($MyInvocation.InvocationName)--$appId--Comparisons--$dateFileUniversal.txt"
    }
    Else{
        Write-host "Skipping $appId"
    }
}
Function Update-ComplaiancePolicyAssignments{}
Function Update-ScriptAssignments{}
Function Update-ProactiveRemediationAssignments{}

Function Get-DeviceConfigurationsOMASettings {
    param($deviceConfiguration)

    #$deviceConfigurationWithOMASettings = Invoke-mgGraphRequest -uri "/beta/devicemanagement/deviceconfigurations/$deviceConfigurationID"
    $deviceConfigurationOMASettings = $deviceConfiguration.AdditionalProperties.omaSettings
    Foreach ($setting in $deviceConfigurationOMASettings) {
        if ([string]$(($setting).secretReferenceValueId) -eq '') {
            $settingvalue = [string]$(($setting).value)
                
        }
        else {
            TRY {
                $settingvalue = (Invoke-MgGraphRequest -Method Get -OutputType PSObject -URI "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/$($deviceConfiguration.id)/getOmaSettingPlainTextValue(secretReferenceValueId='$([string]($setting).secretReferenceValueId)`'`)").value
            }
            Catch {}
                
        }
        $settingCatalogInstance = $settingsCatalog | Where-Object { $_.omaUri -eq ($setting).omaUri }
        if ($settingvalue.length -gt 32767) { Write-Warning "Setting Length Greater than 32767."; Continue }
        $hash = New-Object PSObject 
        $hash | Add-Member -type NoteProperty -name Name -Value ($deviceConfiguration).displayname
        $hash | Add-Member -type NoteProperty -name CombinedNameSetting -Value $(($deviceConfiguration).displayname + ($setting).omaUri)
        $hash | Add-Member -type NoteProperty -name id -Value ($deviceConfiguration).id
        $hash | Add-Member -type NoteProperty -name settingType -Value ($setting).'@odata.type'
        $hash | Add-Member -type NoteProperty -name settingDefinitionId -Value ($setting).omaUri
        $hash | Add-Member -type NoteProperty -name settingValue -Value $([string]$settingvalue)
        $hash | Add-Member -type NoteProperty -name configurationSettingsId -Value $settingCatalogInstance.Id
        #$hash | Add-Member -type NoteProperty -name docLink -Value $(($global:settingsCatalog | Where-Object { ($_.baseUri + $_.offsetUri) -eq ($setting).omauri } | Select-Object infoUrls).infoURLs)
        Write-Output $hash
        remove-variable hash
    
    }
}
function Get-SettingValuesandChildren {
    param(
        [parameter(Mandatory = $true)]
        $var_item,
        [parameter(Mandatory = $true)]
        $setting
    )
    $outputArray = @()
    
            
    If ($setting.settingInstance) {
                
        $settingInstance = ($setting).settingInstance

    }
    Else {
        $settingInstance = $($setting)
    }           
    $settingCatalogInstance = $settingsCatalog | Where-Object { $_.Id -eq ($settingInstance).settingDefinitionId }
    $valueName = ""
    $new_settingDefinitionId = "./" + ((($settingInstance).settingDefinitionId) -replace "_", "/")
    $hash = New-Object PSObject 
    $hash | Add-Member -type NoteProperty -name Name -Value ($var_item).name
    $hash | Add-Member -type NoteProperty -name CombindedName -Value $(($var_item).name + $new_settingDefinitionId)
    $hash | Add-Member -type NoteProperty -name id -Value ($var_item).id
    $hash | Add-Member -type NoteProperty -name settingType -Value ($settingInstance).'@odata.type'
    $hash | Add-Member -type NoteProperty -name settingDefinitionId -Value $($settingCatalogInstance.BaseURI + $settingCatalogInstance.OffsetUri)
    $hash | Add-Member -type NoteProperty -name configurationSettingsId -Value $settingCatalogInstance.Id
                
    if ( [bool]($settingInstance.keys -match "simpleSettingCollectionValue")) {
            
        $hash | Add-Member -type NoteProperty -name settingValue -Value ($settingInstance).simpleSettingCollectionValue.value
        $valuename = "simpleSettingCollectionValue"
    }
    elseif ([bool]($settingInstance.keys -match "choiceSettingValue")) {
        $hash | Add-Member -type NoteProperty -name settingValue -Value ($(($settingInstance).choiceSettingValue.value) -replace (($settingInstance).settingDefinitionId + "_"), "" )
        $valuename = "choiceSettingValue"
    }
    elseif ([bool]($settingInstance.keys -match "simpleSettingValue")) {
        $hash | Add-Member -type NoteProperty -name settingValue -Value ($settingInstance).simpleSettingValue.value
        $valuename = "simpleSettingValue"
    }
    elseif ([bool]($settingInstance.keys -match "groupSettingCollectionValue")) {
        $hash | Add-Member -type NoteProperty -name settingValue -Value ($settingInstance).groupSettingCollectionValue.value
        $valuename = "groupSettingCollectionValue"
    }
    else {
        $hash | Add-Member -type NoteProperty -name settingValue -Value "Unknown"
        $valuename = "unknown"
        Write-host "The following setting led to an unknown:" + $settinginstance
        write-host $settingInstance.keys
                
                
    }

    $hash | Add-Member -type NoteProperty -name settingDefinitionIdUNDERSCORE -Value ($settingInstance).settingDefinitionId
    $hash | Add-Member -type NoteProperty -name settingInstanceTemplateReference -Value ($settingInstance).settingInstanceTemplateReference
    #$hash | Add-Member -type NoteProperty -name docLink -Value $(If ($setting.SettingDefinitions) { ($setting.SettingDefinitions).infoURLs }else { "Unknown" })

    #$outputArray +=$hash
    $hash
    Remove-variable hash
            
            
            
    if (($settingInstance).$valueName.children) { Write-host "Getting children of type $valuename"; foreach ($item in (($settingInstance).$valueName.children)) { write-host $item.settingDefinitionId; Get-SettingValuesandChildren $var_item $item } }

}

Function Get-ConfigurationPolicySettings {
    param($devicePolicy)
    $devicePolicySettings = Invoke-MGGraphRequest -uri "/beta/devicemanagement/configurationpolicies/$($devicePolicy.id)/Settings?expand=SettingDefinitions" | Get-NextLink
    $settingCatalogInstance = $settingsCatalog | Where-Object { $_.Id -eq ($settingInstance).settingDefinitionId }
    
    foreach ($setting in $devicePolicySettings) {
        Get-SettingValuesandChildren $devicePolicy $setting
        
    }
    Remove-variable devicePolicy

}

Function Get-GroupPolicyConfigurationSettings {
    param($groupPolicyConfiguration)
    $policyDefinitionValues = Invoke-MGGraphRequest -URI "/beta/devicemanagement/grouppolicyconfigurations/$($groupPolicyConfiguration.id)/DefinitionValues?expand=definition" | Get-NextLink
    $policyDefinitionValues |
    Foreach-Object {
            
        $definition = (Invoke-MGGraphRequest -uri "/beta/devicemanagement/grouppolicydefinitions/$($_.definition.id)")
        $_.definition.categoryPath = $definition.categoryPath
        $_.definition.explainText = $definition.explainText
    }
    
    $groupPolicyConfiguration.DefinitionValues = $policyDefinitionValues

    
    Foreach ($value in $groupPolicyConfiguration.DefinitionValues) {
        $settingCatalogInstance = $settingsCatalog | Where-Object -Property DisplayName -eq $value.definition.displayName
        Add-Member -NotePropertyMembers @{"DisplayName" = "$($value.definition.displayName)" }  -InputObject $value
        Add-Member -NotePropertyMembers @{"categoryPath" = "$($value.definition.categorypath)" } -InputObject $value
        Add-Member -NotePropertyMembers @{"definitionId" = "$($value.definition.Id)" }           -InputObject $value
        Add-Member -NotePropertyMembers @{"ExplainText" = "$($value.definition.ExplainText)" }  -InputObject $value
        Add-Member -NotePropertyMembers @{"ClassType" = "$($value.definition.ClassType)" }    -InputObject $value
        Add-Member -NotePropertyMembers @{"ConfigurationSettingsId" = "$($settingCatalogInstance.id)" }    -InputObject $value
    }
    $groupPolicyConfiguration.DefinitionValues.definition
}

Function Get-ResourcesAssignedToGroup {
    param ($groupid)
    $group = Get-MgGroup -GroupId $groupId
    $configs = Get-AllConfigProfiles -assignedGroupId $groupid
    $compliancePolicies = Get-AllCompliancePolicies -assignedGroupId $groupid
    $apps = Get-AllAppsForGroup -groupId $groupid
    $autopilotProfile = Get-AutoPilotProfileFromGroup -assignedGroupId $groupid
    $enrollmentConfiguration = Get-EnrollmentConfigurationFromGroup -assignedGroupId $groupid
    $scripts = Get-AllScripts -assignedGroupId $groupid
    $PRscripts = Get-ProactiveRemediationScriptsFromGroup -assignedGroupId $groupid
    $output = new-object psobject
    $output | Add-Member -notePropertyMembers @{"group" = $group }
    $output | Add-Member -notePropertyMembers @{"deviceConfigurations" = $configs.deviceConfigurations }
    $output | Add-Member -notePropertyMembers @{"configurationPolicies" = $configs.configurationPolicies }
    $output | Add-Member -notePropertyMembers @{"groupPolicyConfigurations" = $configs.groupPolicyConfigurations }
    $output | Add-Member -notePropertyMembers @{"compliancePolicies" = $compliancePolicies }
    $output | Add-Member -notePropertyMembers @{"apps" = $apps }
    $output | Add-Member -notePropertyMembers @{"autopilotProfile" = $autopilotProfile }
    $output | Add-Member -notePropertyMembers @{"enrollmentConfiguration" = $enrollmentConfiguration }
    $output | Add-Member -notePropertyMembers @{"scripts" = $scripts }
    $output | Add-Member -notePropertyMembers @{"PRscripts" = $PRscripts }
    $output
}

Function Compare-ResourcesAssignedToGroup {
    param($referenceObject, $differenceObject)
    #$referenceObject.configurationPolicies = $referenceObject.configurationPolicies | Select-Object -Property *,@{name='displayName';expression={$($_.Name)}}
    #$differenceObject.configurationPolicies = $differenceObject.configurationPolicies| Select-Object -Property *,@{name='displayName';expression={$($_.Name)}}
    Write-Verbose "Comparing $($referenceObject.Group.DisplayName) to $($differenceObject.Group.DisplayName)"
    $confpol    =   Compare-Object -ReferenceObject $($referenceObject.configurationPolicies |
             Select-Object -Property *, @{name = 'displayName'; expression = { $($_.Name) } })      -DifferenceObject  $($differenceObject.configurationPolicies |
                                                                                  Select-Object -Property *, @{name = 'displayName'; expression = { $($_.Name) } }) -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $devconf    =   Compare-Object -ReferenceObject $referenceObject.deviceConfigurations           -DifferenceObject  $differenceObject.deviceConfigurations       -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $gpConf     =   Compare-Object -ReferenceObject $referenceObject.groupPolicyConfigurations      -DifferenceObject  $differenceObject.groupPolicyConfigurations  -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $comppol    =   Compare-Object -ReferenceObject $referenceObject.compliancePolicies             -DifferenceObject  $differenceObject.compliancePolicies         -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $apps       =   Compare-Object -ReferenceObject $referenceObject.apps                           -DifferenceObject  $differenceObject.apps                       -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $approfile  =   Compare-Object -ReferenceObject $referenceObject.autopilotProfile               -DifferenceObject  $differenceObject.autopilotProfile           -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $enrollconf =   Compare-Object -ReferenceObject $referenceObject.enrollmentConfiguration        -DifferenceObject  $differenceObject.enrollmentConfiguration    -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $scripts    =   Compare-Object -ReferenceObject $referenceObject.scripts                        -DifferenceObject  $differenceObject.scripts                    -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    $prscripts  =   Compare-Object -ReferenceObject $referenceObject.PRscripts                      -DifferenceObject  $differenceObject.PRscripts                  -property displayName -IncludeEqual -ErrorAction "silentlyContinue"
    
    $output = New-Object psobject
    $output | Add-Member -NotePropertyMembers @{
        "configurationPolicies"     = $confpol 
        "deviceConfigurations"      = $devconf 
        "groupPolicyConfigurations" = $gpConf  
        "compliancePolicies"        = $comppol     
        "apps"                      = $apps     
        "autoPilotProfile"          = $approfile     
        "enrollmentConfiguration"   = $enrollconf    
        "scripts"                   = $scripts     
        "PRscripts"                 = $prscripts     
    
    }
    Write-Output $output
}

Function Get-ManagedDevicesFromGroup {
    param($groupId)

    $group = Get-MgGroupMember -GroupId $groupId -All
    If (($group.additionalproperties).count -gt 0) {
        $group.additionalproperties | foreach-object {
            Get-MgDeviceManagementManagedDevice -Filter "AzureAdDeviceId eq '$($_.deviceId)'" -Property Id } |
        Foreach {
            Get-MgDeviceManagementManagedDevice -ManagedDeviceId $_.Id -expand DetectedApps
        }
        Write-Output $groupMembers
    }
}

Function Get-DeviceMonitorItems{
    param(
        $targetGroupId,
        $deviceList

    )
    $rootCertDeviceRunState = Get-MgDeviceManagementDeviceHealthScriptDeviceRunState -DeviceHealthScriptId 66819f4f-273b-4acb-a064-c3deaa175c3e -All
    $hashDeviceRunState = Get-MgDeviceManagementDeviceHealthScriptDeviceRunState -DeviceHealthScriptId 0dff76b9-20cf-4eee-8b6b-692f78fa649c
    $ScriptRunState = Get-MgDeviceManagementScriptDeviceRunState -DeviceManagementScriptId b06ea063-e15a-483e-9d3d-11156a84ea22
    $renameState = Get-MgDeviceManagementRemoteActionAudit -all -Filter "Action eq 'setDeviceName'"|select ActionState,deviceDisplayName,DeviceOwnerUserPrincipalName,InitiatedbyUserPrincipalName,RequestDateTime
    
    Foreach($device  in $deviceList){
        $outfilepath = "C:\git\3MMD-Conversion\Reporting"
        $listofProfiles = Get-ConfigurationPolicyReportForDevice -deviceId $device.id -outFolder $outfilepath
        $device|
        Select id,userdisplayName,userPrincipalName, EnrollmentProfileName,SerialNumber,@{
            Name="LastSyncDateTimeLocal";Expression={(Get-Date($device.LastSyncDateTime)).AddHours(-5)}},@{
            Name="InAutoPilot";Expression={$device.SerialNumber -in $autopilotdeviceidentities.SerialNumber}},@{
            Name="HasAvecto";Expression={$null -ne $($device.DetectedApps|where displayName -like "Privilege Management*")}},@{
            Name="RootCertPRState";Expression={$rootCertDeviceRunState |where {$_.Id -eq "66819f4f-273b-4acb-a064-c3deaa175c3e:$($device.id)"}|Select DetectionState,RemediationState,LastSyncDateTime,LastStateUpdateDateTime}},@{
            Name="HashPRState";Expression={$hashDeviceRunState |where {$_.Id -eq "0dff76b9-20cf-4eee-8b6b-692f78fa649c:$($device.id)"}|Select DetectionState,RemediationState,LastSyncDateTime,LastStateUpdateDateTime}},@{
            Name="InvokeMMDTasksScript";Expression={$ScriptRunState |where {$_.Id -eq "b06ea063-e15a-483e-9d3d-11156a84ea22:$($device.id)"}|Select RunState,ErrorDescription,LastStateUpdateDateTime}},@{
            Name="PCRenameState";Expression={$renameState |where {$_.deviceDisplayName -eq $($device.id)}|Select ActionState}},@{
            Name="ListofConfigProfiles";Expression={$listofProfiles.policyName}},
            AzureADDeviceID
        }
    
}

Function Rename-ManagedDevice{
    param(
        $deviceId,
        $deviceNamePattern ="3MMD-%RAND:10%"
    )

    $bodyDeviceName_inner = $(@($deviceId|foreach{"""$($_)"":""$deviceNamePattern"""}) -join ",")
    $bodyDeviceName = "`{$bodyDeviceName_inner`}"
    $body = @{
        action="setDeviceAction"
        platform="windows"
        deviceIds=@($deviceId)
        restartNow=$false
        deviceName="$bodyDeviceName"
        realAction="setDeviceName"
        actionName="setDeviceName"
        }

    Invoke-MgGraphRequest -uri "https://graph.microsoft.com/beta/deviceManagement/managedDevices/executeAction" -Method POST -Body $body
}

Function Get-ConversionDeviceReport{


    $date = $(Get-Date -format FileDateTimeUniversal)
    $apDevicesTest  = Get-ManagedDevicesFromGroup -groupId $autoPilotTransitionGroupTest    | Convertto-Json   -Depth 10   | Tee-Object -filePath C:\Temp\apDevicesTest.JSON
    $apDevicesFirst = Get-ManagedDevicesFromGroup -groupId $autoPilotTransitionGroupFirst   | Convertto-Json   -Depth 10   | Tee-Object -filePath C:\Temp\apDevicesFirst.JSON
    $apDevicesFast  = Get-ManagedDevicesFromGroup -groupId $autoPilotTransitionGroupFast    | Convertto-Json    -Depth 10  | Tee-Object -filePath C:\Temp\apDevicesFast.JSON
    $apDevicesBroad = Get-ManagedDevicesFromGroup -groupId $autoPilotTransitionGroupBroad   | Convertto-Json   -Depth 10   | Tee-Object -filePath C:\Temp\apDevicesBroad.JSON
    $apDevices      = $apDevicesTest + $apDevicesFirst + $apDevicesFast + $apDevicesBroad
    
    $DeviceMonitorItems = Get-DeviceMonitorItems -deviceList $apDevices
    $DeviceMonitorItems | Export-CSV C:\git\3MMD-Conversion\ConversionDevices--$date.csv -NoTypeInformation
    $deviceMonitorItems.ListofConfigProfiles | Group | Sort count | Export-CSV -Path "C:\git\3MMD-Conversion\ConversionDevices--GroupedProfileNames-$date.csv"
}
Function Export-JsonCollections{
    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceAppMgtMobileApp     -Expand assignments -All                |
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceAppManagementMobileApps.JSON -encoding utf8
    }

    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceManagementDeviceConfiguration -Expand assignments -All|
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceManagementConfigurationProfiles.JSON -encoding utf8
    }

    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceManagementConfigurationPolicy -Expand assignments -All|
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceManagementConfigurationPolicies.JSON -encoding utf8
    }

    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceManagementGroupPolicyConfiguration -Expand assignments -All|
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceManagementGroupPolicyConfigurations.JSON -encoding utf8
    }
    
    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceManagementDeviceHealthScript -Expand assignments -All|
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceManagementDeviceHealthScript.JSON -encoding utf8
    }
    
    Start-Job -InitializationScript {. C:\git\3MMD-Conversion\MMD-ConversionModule.ps1} -ScriptBlock {
        Get-MgDeviceManagementScript -Expand assignments -All|
        Foreach{$_|Add-Member -PassThru -NotePropertyMembers @{"_id" = $_.id}}|
        Convertto-Json -Depth 10 |
        Out-File C:\Temp\DeviceManagementScript.JSON -encoding utf8
    }

}

