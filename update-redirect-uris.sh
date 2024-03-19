#!/bin/bash

set -e

NL=$'\n'

eval $(azd env get-values)

msg() {
	echo ">>> $*" >&2
}

confirm() {
	read -p ">>> Continue? [y/N] " -n 1 >&2 && echo >&2
	case "$REPLY" in [yY]) return; esac
	exit 1
}

URI="https://${AZURE_CONTAINER_APP_FQDN}/.auth/login/aad/callback"

URIS=$(az ad app show --id $MS_CLIENT_ID --query web.redirectUris -o tsv)

URIS=$(echo "${URI}${NL}${URIS}" | sort | uniq)

msg "App Client ID:     ${MS_CLIENT_ID}"
msg "App Redirect URI:  ${URI}"
msg "Azure Portal link: https://portal.azure.com/#@${AZURE_TENANT_ID}/view/Microsoft_AAD_RegisteredApps/ApplicationMenuBlade/~/Authentication/appId/${MS_CLIENT_ID}"
msg "Updating to new redirect URIs:${NL}${URIS}"

confirm

az ad app update --id ${MS_CLIENT_ID} --web-redirect-uris ${URIS}

msg 'Done'
