# dx2devops-backstage-containerapp

## Introduction

This project integrates [Backstage] with [Azure Container Apps][ACA] using the [Azure Developer CLI][AZD] (AZD).

It includes [@internal/plugin-auth-backend-module-azure-easyauth-provider](backstage/plugins/auth-backend-module-azure-easyauth-provider)
which is an auth backend module based on [Azure EasyAuth auth provider](https://backstage.io/docs/auth/microsoft/easy-auth/).
The module is compatible with the new backend system introduced in [Backstage v1.24.0](https://backstage.io/docs/releases/v1.24.0) and later
(see https://github.com/backstage/backstage/issues/19476 for more details).

[Backstage]: https://backstage.io
[ACA]: https://learn.microsoft.com/en-us/azure/container-apps/overview
[AZD]: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview
[Azure EasyAuth Provider]: https://backstage.io/docs/auth/microsoft/easy-auth/

## Local Development

Follow these steps to build and test the container locally:

```console
$ docker compose build
$ docker compose up -d
$ xdg-open http://localhost:7007
```

## Azure Deployment

First, register a Microsoft Entra ID (ME-ID) app for the user authentication
([see doc](https://learn.microsoft.com/ja-jp/entra/identity-platform/scenario-web-app-sign-user-app-registration)).

You will need the following information from your app:

- Tenant ID
- Client ID
- Client Secret

Then, deploy the Azure container app using Azure CLI (az) and Azure Developer CLI (azd):

```console
$ azd auth login
$ azd env new <ENV-NAME>
$ azd env set MS_TENANT_ID <TENANT-ID>
$ azd env set MS_CLIENT_ID <CLIENT-ID>
$ azd env set MS_CLIENT_SECRET <CLIENT-SECRET>
$ azd provision               # Provision Azure container app resources
$ azd deploy                  # Build and deploy a container to the app

$ az login
$ ./update-redirect-uris.sh   # Update redirect URIs of the ME-ID app using az
```
