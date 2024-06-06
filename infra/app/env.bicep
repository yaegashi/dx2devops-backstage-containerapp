param containerAppsEnvironmentName string
param logAnalyticsWorkspaceName string
param storageAccountName string
param location string
param tags object

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  resource fileService 'fileServices' = {
    name: 'default'
    resource data 'shares' = {
      name: 'data'
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' existing = {
  name: logAnalyticsWorkspaceName
}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' = {
  name: containerAppsEnvironmentName
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
  }
  resource data 'storages' = {
    name: 'data'
    properties: {
      azureFile: {
        accessMode: 'ReadWrite'
        accountName: storage.name
        accountKey: storage.listKeys().keys[0].value
        shareName: storage::fileService::data.name
      }
    }
  }
}

output id string = containerAppsEnvironment.id
output name string = containerAppsEnvironment.name
output customDomainVerificationId string = containerAppsEnvironment.properties.customDomainConfiguration.customDomainVerificationId
