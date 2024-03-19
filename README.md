# dx2devops-backstage-containerapp

## Introduction

DX2 DevOps solution for [Backstage] on [Azure Container Apps][ACA] using the [Azure Developer CLI][AZD] (AZD).

It utilizes the [Azure EasyAuth Provider](https://backstage.io/docs/auth/microsoft/easy-auth/) for the user authentication.

[Backstage]: https://backstage.io
[ACA]: https://learn.microsoft.com/en-us/azure/container-apps/overview
[AZD]: https://learn.microsoft.com/en-us/azure/developer/azure-developer-cli/overview

## Local development

Locally build and test the container:

```console
$ docker compose build
$ docker compose up -d
$ xdg-open http://localhost:7007
```

## Azure deployment

Register a Microsoft Entra ID (ME-ID) app for the user authentication
([see doc](https://learn.microsoft.com/ja-jp/entra/identity-platform/scenario-web-app-sign-user-app-registration)).
You need the following information of your app:

- Tenant ID
- Client ID
- Client Secret

Deploy Azure container app using Azure CLI (az) and Azure Developer CLI (azd):

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

