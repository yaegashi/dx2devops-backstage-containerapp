targetScope = 'subscription'

@minLength(1)
@maxLength(64)
param environmentName string

@minLength(1)
param location string

param principalId string

param resourceGroupName string = ''

param webAppExists bool = false

param keyVaultName string = ''

param dbName string = ''

param dbAdminUser string = 'adminuser'

@secure()
param dbAdminPass string

param containerRegistryName string = ''

param logAnalyticsName string = ''

param applicationInsightsName string = ''

param applicationInsightsDashboardName string = ''

param storageAccountName string = ''

param userAssignedIdentityName string = ''

param containerAppsEnvironmentName string = ''

param containerAppName string = ''

param msTenantId string

param msClientId string

@secure()
param msClientSecret string

@secure()
param authKeySecret string

param tz string = 'Asia/Tokyo'

param appCertificateExists bool = false

param dnsZoneSubscriptionId string = ''

param dnsZoneResourceGroupName string = ''

param dnsZoneName string = ''

param dnsRecordName string = ''

param utcValue string = utcNow()

var abbrs = loadJsonContent('./abbreviations.json')

var tags = {
  'azd-env-name': environmentName
}

#disable-next-line no-unused-vars
var resourceToken = toLower(uniqueString(subscription().id, environmentName, location))

var dnsEnable = !empty(dnsZoneResourceGroupName) && !empty(dnsZoneName) && !empty(dnsRecordName)
var appCustomDomainName = dnsEnable ? '${dnsRecordName}.${dnsZoneName}' : ''

resource dnsZoneRG 'Microsoft.Resources/resourceGroups@2021-04-01' existing = if (dnsEnable && !appCertificateExists) {
  scope: subscription(empty(dnsZoneSubscriptionId) ? subscription().subscriptionId : dnsZoneSubscriptionId)
  name: dnsZoneResourceGroupName
}

module dnsTXT './app/dns-txt.bicep' = if (dnsEnable && !appCertificateExists) {
  name: 'dnsTXT'
  scope: dnsZoneRG
  params: {
    dnsZoneName: dnsZoneName
    dnsRecordName: 'asuid.${dnsRecordName}'
    txt: env.outputs.customDomainVerificationId
  }
}

module dnsCNAME './app/dns-cname.bicep' = if (dnsEnable && !appCertificateExists) {
  name: 'dnsCNAME'
  scope: dnsZoneRG
  params: {
    dnsZoneName: dnsZoneName
    dnsRecordName: dnsRecordName
    cname: appPrep.outputs.fqdn
  }
}

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: !empty(resourceGroupName) ? resourceGroupName : '${abbrs.resourcesResourceGroups}${environmentName}'
  location: location
  tags: tags
}

module keyVault './core/security/keyvault.bicep' = {
  name: 'keyVault'
  scope: rg
  params: {
    name: !empty(keyVaultName) ? keyVaultName : '${abbrs.keyVaultVaults}${resourceToken}'
    location: location
    tags: tags
    principalId: principalId
  }
}

var secrets = [
  {
    name: 'DB-ADMIN-PASS'
    value: dbAdminPass
  }
  {
    name: 'AUTH-KEY-SECRET'
    value: authKeySecret
  }
  {
    name: 'MS-CLIENT-SECRET'
    value: msClientSecret
  }
]

@batchSize(1)
module keyVaultSecrets './core/security/keyvault-secret.bicep' = [
  for secret in secrets: {
    name: 'keyvault-secret-${secret.name}'
    scope: rg
    params: {
      keyVaultName: keyVault.outputs.name
      name: secret.name
      secretValue: secret.value
    }
  }
]

module userAssignedIdentity './app/identity.bicep' = {
  name: 'userAssignedIdentity'
  scope: rg
  params: {
    name: !empty(userAssignedIdentityName)
      ? userAssignedIdentityName
      : '${abbrs.managedIdentityUserAssignedIdentities}${resourceToken}'
    location: location
    tags: tags
  }
}

module keyVaultAccess './core/security/keyvault-access.bicep' = {
  name: 'KeyVaultAccess'
  scope: rg
  params: {
    keyVaultName: keyVault.outputs.name
    principalId: userAssignedIdentity.outputs.principalId
  }
}

module containerRegistryAccess './core/security/registry-access.bicep' = {
  dependsOn: [containerRegistry]
  name: 'containerRegistryAccess'
  scope: rg
  params: {
    containerRegistryName: containerRegistry.outputs.name
    principalId: userAssignedIdentity.outputs.principalId
  }
}

module psql './core/database/postgresql/flexibleserver.bicep' = {
  name: 'psql'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(dbName) ? dbName : '${abbrs.dBforPostgreSQLServers}${resourceToken}'
    administratorLogin: dbAdminUser
    administratorLoginPassword: dbAdminPass
    version: '15'
    sku: {
      name: 'Standard_B1ms'
      tier: 'Burstable'
    }
    storage: {
      storageSizeGB: 32
    }
    allowAzureIPsFirewall: true
  }
}

module containerRegistry './core/host/container-registry.bicep' = {
  name: 'containerRegistry'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(containerRegistryName) ? containerRegistryName : '${abbrs.containerRegistryRegistries}${resourceToken}'
    workspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module monitoring './core/monitor/monitoring.bicep' = {
  name: 'monitoring'
  scope: rg
  params: {
    location: location
    tags: tags
    logAnalyticsName: !empty(logAnalyticsName)
      ? logAnalyticsName
      : '${abbrs.operationalInsightsWorkspaces}${resourceToken}'
    applicationInsightsName: !empty(applicationInsightsName)
      ? applicationInsightsName
      : '${abbrs.insightsComponents}${resourceToken}'
    applicationInsightsDashboardName: !empty(applicationInsightsDashboardName)
      ? applicationInsightsDashboardName
      : '${abbrs.portalDashboards}${resourceToken}'
  }
}

module storageAccount './core/storage/storage-account.bicep' = {
  name: 'storageAccount'
  scope: rg
  params: {
    location: location
    tags: tags
    name: !empty(storageAccountName) ? storageAccountName : '${abbrs.storageStorageAccounts}${resourceToken}'
  }
}

var xTZ = !empty(tz) ? tz : 'Asia/Tokyo'
var xContainerAppsEnvironmentName = !empty(containerAppsEnvironmentName)
  ? containerAppsEnvironmentName
  : '${abbrs.appManagedEnvironments}${resourceToken}'
var xContainerAppName = !empty(containerAppName) ? containerAppName : '${abbrs.appContainerApps}${resourceToken}'

resource existingApp 'Microsoft.App/containerApps@2023-08-01-preview' existing = if (webAppExists) {
  scope: rg
  name: xContainerAppName
}

module env './app/env.bicep' = {
  name: 'env'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentName: xContainerAppsEnvironmentName
    logAnalyticsWorkspaceName: monitoring.outputs.logAnalyticsWorkspaceName
    storageAccountName: storageAccount.outputs.name
  }
}

module appPrep './app/app-prep.bicep' = if (dnsEnable && !appCertificateExists) {
  dependsOn: [dnsTXT]
  name: 'appPrep'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentName: env.outputs.name
    containerAppName: xContainerAppName
    appCustomDomainName: appCustomDomainName
  }
}

module app './app/app.bicep' = {
  dependsOn: [dnsCNAME]
  name: 'app'
  scope: rg
  params: {
    location: location
    tags: tags
    containerAppsEnvironmentName: env.outputs.name
    containerAppName: xContainerAppName
    containerRegistryLoginServer: containerRegistry.outputs.loginServer
    userAssignedIdentityName: userAssignedIdentity.outputs.name
    storageAccountName: storageAccount.outputs.name
    appCustomDomainName: appCustomDomainName
    imageName: webAppExists ? existingApp.properties.template.containers[0].image : ''
    appDbUrl: 'postgresql://${dbAdminUser}:${dbAdminPass}@${psql.outputs.POSTGRES_DOMAIN_NAME}?sslmode=require'
    authKeySecret: authKeySecret
    msTenantId: msTenantId
    msClientId: msClientId
    msClientSecret: msClientSecret
    tz: xTZ
  }
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output AZURE_SUBSCRIPTION_ID string = subscription().subscriptionId
output AZURE_RESOURCE_GROUP_NAME string = rg.name
output AZURE_KEY_VAULT_NAME string = keyVault.outputs.name
output AZURE_KEY_VAULT_ENDPOINT string = keyVault.outputs.endpoint
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.outputs.name
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.outputs.loginServer
output AZURE_CONTAINER_APP_NAME string = app.outputs.name
output AZURE_CONTAINER_APP_FQDN string = app.outputs.fqdn
output APP_CERTIFICATE_EXISTS bool = !empty(appCustomDomainName)
output SERVICE_WEB_RESOURCE_EXISTS bool = !empty(app.outputs.id)
