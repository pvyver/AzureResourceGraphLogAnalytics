# variables
$location = "your location"
$resourceGroup = "your resource group for the collection endpoint and data collection rule"
$logAnalyticsWorkspaceResourceId = "your log analytcs workspace resource id"
$subscriptionId = "your subscription id"

function get-azCachedAccessToken() {
    $currentAzureContext = Get-AzContext
    $azProfile = [Microsoft.Azure.Commands.Common.Authentication.Abstractions.AzureRmProfileProvider]::Instance.Profile
    $profileClient = New-Object Microsoft.Azure.Commands.ResourceManager.Common.RMProfileClient($azProfile)
    $token = $profileClient.AcquireAccessToken($currentAzureContext.Tenant.TenantId)
    $token.AccessToken
}

# get token
$token = get-azCachedAccessToken 
$authHeader = @{
    'Authorization' = "Bearer $token"
    'Content-Type'  = "application/json"
}

# get table
$tableName = "Resources_CL"
$uri = "https://management.azure.com$($logAnalyticsWorkspaceResourceId)/tables/$($tableName)?api-version=2021-12-01-preview"
$table = Invoke-RestMethod -Method Get -Uri $uri -Headers $authHeader -SkipHttpErrorCheck
 
if ($table.error.code -eq "ResourceNotFound") {
    # create table
    Write-Output "Creating new table '$tableName'.."
    $uri = "https://management.azure.com$($logAnalyticsWorkspaceResourceId)/tables/$($tableName)?api-version=2021-12-01-preview"
    $jsonBody = [String](Get-Content -Path .\table.json)
    Invoke-RestMethod -Method Put -Uri $uri -Headers $authHeader -Body $jsonBody 
}
else {
    Write-Output "Table '$tableName' found.."
}

# get dataCollectionEndpoint
$dataCollectionEndpointName = "dce-weu-tst-resources"
$dataCollectionEndpoint = $null
$dataCollectionEndpoint = Search-AzGraph -Query "resources | where name == '$dataCollectionEndpointName'" -Subscription $subscriptionId 
if ($dataCollectionEndpoint.Count -eq 0) {
    # deploy dataCollectionEndpoint 
    Write-Output "Deploying Data Collection Endpoint '$dataCollectionEndpointName'.."
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup -Name "D_dataCollectionEndpoint" -TemplateFile .\templates\dataCollectionEndpoint.json `
        -dataCollectionEndpointName $dataCollectionEndpointName `
        -location $location | Out-Null
}
else {
    Write-Output "Data Collection Endpoint '$dataCollectionEndpointName' found.."
}
    

# get dataCollectionRule
$dataCollectionRuleName = "dcr-weu-tst-resources"
$dataCollectionRule = $null
$dataCollectionRule = Search-AzGraph -Query "resources | where name == '$dataCollectionRuleName'" -Subscription $subscriptionId
if ($dataCollectionRule.Count -eq 0) {
    # deploy dataCollectionRule
    Write-Output "Deploying Data Collection Rule '$dataCollectionRuleName'.."
    New-AzResourceGroupDeployment -ResourceGroupName $resourceGroup -Name "D_dataCollectionRule" -TemplateFile .\templates\dataCollectionRules.json `
        -dataCollectionRuleName $dataCollectionRuleName `
        -location $location `
        -workspaceResourceId $logAnalyticsWorkspaceResourceId `
        -endpointResourceId "/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionEndpoints/$dataCollectionEndpointName"  | Out-Null
}
else {
    Write-Output "Data Collection Rule '$dataCollectionRuleName' found.."
}