param containerAppsEnvironmentName string
param containerAppName string
param location string = resourceGroup().location
param tags object = {}
param storageAccountName string
param containerRegistryLoginServer string
param userAssignedIdentityName string
param imageName string
param kvAppDbUrl string
param msTenantId string = ''
param msClientId string = ''
#disable-next-line secure-secrets-in-params
param kvMsClientSecret string = ''
param tz string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  resource blobService 'blobServices' = {
    name: 'default'
    resource data 'containers' = {
      name: 'token-store'
    }
  }
}

// See https://learn.microsoft.com/en-us/rest/api/storagerp/storage-accounts/list-service-sas
var sas = storage.listServiceSAS(
  '2022-05-01',
  {
    canonicalizedResource: '/blob/${storage.name}/token-store'
    signedProtocol: 'https'
    signedResource: 'c'
    signedPermission: 'rwdl'
    signedExpiry: '3000-01-01T00:00:00Z'
  }
).serviceSasToken
var sasUrl = 'https://${storage.name}.blob.${environment().suffixes.storage}/token-store?${sas}'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' existing = {
  name: containerAppsEnvironmentName
}

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' = {
  name: containerAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${userAssignedIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 7007
      }
      registries: [
        {
          server: containerRegistryLoginServer
          identity: userAssignedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'app-db-url'
          keyVaultUrl: kvAppDbUrl
          identity: userAssignedIdentity.id
        }
        {
          name: 'microsoft-provider-authentication-secret'
          keyVaultUrl: kvMsClientSecret
          identity: userAssignedIdentity.id
        }
        {
          name: 'token-store-url'
          value: sasUrl
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'main'
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            { name: 'NODE_OPTIONS', value: '--max-http-header-size=32768' }
            { name: 'PORT', value: '7007' } // for containerapps-helloworld
            { name: 'TZ', value: tz }
            { name: 'WEBSITE_SKU', value: 'Basic' }
            { name: 'WEBSITE_AUTH_ENABLED', value: 'true' }
            { name: 'WEBSITE_AUTH_DEFAULT_PROVIDER', value: 'AzureActiveDirectory' }
            { name: 'WEBSITE_AUTH_TOKEN_STORE', value: 'true' }
            { name: 'APP_CONFIG_auth_environment', value: '"production"' }
            { name: 'APP_CONFIG_auth_providers_easyAuth', value: '{}' }
            { name: 'APP_CONFIG_backend_database_client', value: '"pg"' }
            { name: 'APP_CONFIG_backend_database_connection', secretRef: 'app-db-url' }
            { name: 'APP_CONFIG_backend_auth_keys', value: '[{"secret":"secret"}]' }
          ]
          probes: [
            {
              type: 'Startup'
              httpGet: {
                path: '/'
                port: 7007
                scheme: 'HTTP'
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              timeoutSeconds: 1
              successThreshold: 1
              failureThreshold: 30
            }
          ]
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  resource authConfigs 'authConfigs' =
    if (!empty(msTenantId) && !empty(msClientId)) {
      name: 'current'
      properties: {
        identityProviders: {
          azureActiveDirectory: {
            registration: {
              clientId: msClientId
              clientSecretSettingName: 'microsoft-provider-authentication-secret'
              openIdIssuer: 'https://sts.windows.net/${msTenantId}/v2.0'
            }
            validation: {
              allowedAudiences: [
                'api://${msClientId}'
              ]
            }
            login: {
              loginParameters: ['scope=openid profile email offline_access']
            }
          }
        }
        platform: {
          enabled: true
        }
        login: {
          // https://github.com/backstage/backstage/issues/21654
          allowedExternalRedirectUrls: [
            'https://${containerApp.properties.configuration.ingress.fqdn}'
          ]
          tokenStore: {
            enabled: true
            azureBlobStorage: {
              sasUrlSettingName: 'token-store-url'
            }
          }
        }
      }
    }
}

output defaultDomain string = containerAppsEnvironment.properties.defaultDomain
output id string = containerApp.id
output name string = containerApp.name
output fqdn string = containerApp.properties.configuration.ingress.fqdn
