
# Azure Deployment

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
