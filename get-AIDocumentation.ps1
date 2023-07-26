# Set up the OpenAI API client
Function Get-AIDocumentation{
param(
    [Parameter(Mandatory=$false)]
    [string]$openai_api_key="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",
    [Parameter(Mandatory=$false)]
    [string]$openai_engine = "code-davinci-002",
    [Parameter(Mandatory=$false)]
    [string]$powershell_code = ($(Get-Content 'C:\git\VNetInformatique--SyncroMSP\AdminPassword\Add vnetadmin Account + Password.ps1').ToString()).replace("`n","`n"""))

# Set the headers for the API request
$headers = @{"Content-Type"="application/json"; "Authorization"="Bearer $openai_api_key"}
#Convert powershell_code friom an arry ato a single string
$powershell_code = @'
The top ten useful but usually unkown powershell tips are:

'@

# Define the prompt that will be used to generate the explanation
$prompt = "$powershell_code"

# Set the parameters for the API request
$params = @{
    "prompt" = $prompt
    "model" = $openai_engine
    "temperature" = 0.7
    "max_tokens" = 4096
    "top_p" = 1
    "frequency_penalty" = 0
    "presence_penalty" = 0
    "stop" = @("`n`n")
}

# Send the API request
$response = Invoke-RestMethod `
    -Method POST `
    -Uri "https://api.openai.com/v1/completions" `
    -Headers $headers `
    -Body (ConvertTo-Json -InputObject $params)

# Extract the natural language explanation from the API response
$explanation = $response.choices[0].text.Trim()

# Print the explanation
Write-Output $explanation
}
Get-AIDocumentation