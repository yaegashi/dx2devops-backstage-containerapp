param containerAppsEnvironmentName string
param containerAppName string
param appCustomDomainName string
param location string = resourceGroup().location
param tags object = {}

resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2023-08-01-preview' existing = {
  name: containerAppsEnvironmentName
}

resource containerApp 'Microsoft.App/containerApps@2023-08-01-preview' = {
  name: containerAppName
  location: location
  tags: union(tags, { 'azd-service-name': 'web' })
  properties: {
    managedEnvironmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 8080
        customDomains: [
          {
            name: appCustomDomainName
            certificateId: null
            bindingType: 'Disabled'
          }
        ]
      }
    }
    template: {
      containers: [
        {
          name: 'hellowrold'
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        }
      ]
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
