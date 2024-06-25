param location string = resourceGroup().location
param tags object = {}
param containerAppsEnvironmentName string
param containerAppName string
param containerRegistryLoginServer string
param storageAccountName string
param appCustomDomainName string = ''
param userAssignedIdentityName string
param imageName string
@secure()
param appDbUrl string
@secure()
param authKeySecret string
param msTenantId string = ''
param msClientId string = ''
@secure()
param msClientSecret string = ''
param tz string

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: userAssignedIdentityName
}

resource storage 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: storageAccountName
  resource blobService 'blobServices' = {
    name: 'default'
    resource tokenStore 'containers' = {
      name: 'token-store'
    }
    resource techdocs 'containers' = {
      name: 'techdocs'
    }
  }
}

// See https://learn.microsoft.com/en-us/rest/api/storagerp/storage-accounts/list-service-sas
var sas = storage.listServiceSAS('2022-05-01', {
  canonicalizedResource: '/blob/${storage.name}/token-store'
  signedProtocol: 'https'
  signedResource: 'c'
  signedPermission: 'rwdl'
  signedExpiry: '3000-01-01T00:00:00Z'
}).serviceSasToken
var sasUrl = 'https://${storage.name}.blob.${environment().suffixes.storage}/token-store?${sas}'

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' existing = {
  name: containerAppsEnvironmentName
  resource data 'storages' existing = {
    name: 'data'
  }
}

resource certificate 'Microsoft.App/managedEnvironments/managedCertificates@2023-08-01-preview' = if (!empty(appCustomDomainName)) {
  parent: containerAppsEnvironment
  name: 'cert-${appCustomDomainName}'
  location: location
  tags: tags
  properties: {
    subjectName: appCustomDomainName
    domainControlValidation: 'CNAME'
  }
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
        customDomains: empty(appCustomDomainName)
          ? null
          : [
              {
                name: appCustomDomainName
                certificateId: certificate.id
                bindingType: 'SniEnabled'
              }
            ]
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
          value: '"${appDbUrl}"'
        }
        {
          name: 'auth-key-secrets'
          value: '[{"secret":"${authKeySecret}"}]'
        }
        {
          name: 'microsoft-provider-authentication-secret'
          value: msClientSecret
        }
        {
          name: 'token-store-url'
          value: sasUrl
        }
        {
          name: 'techdocs-name'
          value: '"${storage.name}"'
        }
        {
          name: 'techdocs-key'
          value: '"${storage.listKeys().keys[0].value}"'
        }
      ]
    }
    template: {
      volumes: [
        {
          name: 'data'
          storageName: containerAppsEnvironment::data.name
          storageType: 'AzureFile'
        }
      ]
      containers: [
        {
          name: 'main'
          image: !empty(imageName) ? imageName : 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
          env: [
            // containerapps-helloworld: avoid HTTP 431 error
            { name: 'NODE_OPTIONS', value: '--max-http-header-size=32768 --no-node-snapshot' }
            // containerapps-helloworld: set listening port
            { name: 'PORT', value: '7007' }
            { name: 'TZ', value: tz }
            { name: 'WEBSITE_SKU', value: 'Basic' }
            { name: 'WEBSITE_AUTH_ENABLED', value: 'true' }
            { name: 'WEBSITE_AUTH_DEFAULT_PROVIDER', value: 'AzureActiveDirectory' }
            { name: 'WEBSITE_AUTH_TOKEN_STORE', value: 'true' }
            { name: 'APP_CONFIG_app_baseUrl', value: '"https://${appCustomDomainName}"' }
            { name: 'APP_CONFIG_backend_database_client', value: '"pg"' }
            { name: 'APP_CONFIG_backend_database_connection', secretRef: 'app-db-url' }
            { name: 'APP_CONFIG_backend_auth_keys', secretRef: 'auth-key-secrets' }
            { name: 'APP_CONFIG_backend_baseUrl', value: '"https://${appCustomDomainName}"' }
            { name: 'APP_CONFIG_techdocs_publisher_type', value: '"azureBlobStorage"' }
            { name: 'APP_CONFIG_techdocs_publisher_azureBlobStorage_containerName', value: '"techdocs"' }
            { name: 'APP_CONFIG_techdocs_publisher_azureBlobStorage_credentials_accountName', secretRef: 'techdocs-name' }
            { name: 'APP_CONFIG_techdocs_publisher_azureBlobStorage_credentials_accountKey', secretRef: 'techdocs-key' }
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
          volumeMounts: [
            {
              volumeName: 'data'
              mountPath: '/data'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  resource authConfigs 'authConfigs' = if (!empty(msTenantId) && !empty(msClientId)) {
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
        allowedExternalRedirectUrls: concat(
          ['https://${containerApp.properties.configuration.ingress.fqdn}'],
          empty(appCustomDomainName) ? [] : ['https://${appCustomDomainName}']
        )
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
