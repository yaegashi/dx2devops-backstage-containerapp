# dx2devops-backstage-containerapp

Bootstrap:
```console
$ ./bootstrap.sh
$ git add -A backstage
$ git commit
```

Local container build and test:
```console
$ docker compose build
$ docker compose up -d
$ xdg-open http://localhost:7007
```

Deploy Azure container app:
```console
$ az login
$ azd auth login
$ azd env new <ENV-NAME>
$ azd env set MS_TENANT_ID <GUID>
$ azd env set MS_CLIENT_ID <GUID>
$ azd env set MS_CLIENT_SECRET <SECRET-STRING>
$ azd provision      # First provision without container app
$ ./docker-build.sh  # Build and push to container registry
$ azd provision      # Next provision with container app
```

Backstage diff to enable [Azure EasyAuth Provider](https://backstage.io/docs/auth/microsoft/easy-auth/)
```diff
diff --git a/packages/app/src/App.tsx b/packages/app/src/App.tsx
index 8d62f29..b7370d8 100644
--- a/packages/app/src/App.tsx
+++ b/packages/app/src/App.tsx
@@ -27,12 +27,13 @@ import { entityPage } from './components/catalog/EntityPage';
 import { searchPage } from './components/search/SearchPage';
 import { Root } from './components/Root';
 
-import { AlertDisplay, OAuthRequestDialog } from '@backstage/core-components';
+import { AlertDisplay, OAuthRequestDialog, ProxiedSignInPage, SignInPage } from '@backstage/core-components';
 import { createApp } from '@backstage/app-defaults';
 import { AppRouter, FlatRoutes } from '@backstage/core-app-api';
 import { CatalogGraphPage } from '@backstage/plugin-catalog-graph';
 import { RequirePermission } from '@backstage/plugin-permission-react';
 import { catalogEntityCreatePermission } from '@backstage/plugin-catalog-common/alpha';
+import { configApiRef, useApi } from '@backstage/core-plugin-api';
 
 const app = createApp({
   apis,
@@ -53,6 +54,15 @@ const app = createApp({
       catalogIndex: catalogPlugin.routes.catalogIndex,
     });
   },
+  components: {
+    SignInPage: props => {
+      const configApi = useApi(configApiRef);
+      if (configApi.getString('auth.environment') === 'development') {
+        return <SignInPage {...props} providers={["guest"]} auto />;
+      }
+      return <ProxiedSignInPage {...props} provider="easyAuth" />;
+    }
+  },
 });
 
 const routes = (
diff --git a/packages/backend/src/plugins/auth.ts b/packages/backend/src/plugins/auth.ts
index 77eb6aa..6cfcc01 100644
--- a/packages/backend/src/plugins/auth.ts
+++ b/packages/backend/src/plugins/auth.ts
@@ -5,6 +5,7 @@ import {
 } from '@backstage/plugin-auth-backend';
 import { Router } from 'express';
 import { PluginEnvironment } from '../types';
+import { DEFAULT_NAMESPACE, stringifyEntityRef } from '@backstage/catalog-model';
 
 export default async function createPlugin(
   env: PluginEnvironment,
@@ -49,6 +50,33 @@ export default async function createPlugin(
           // resolver: providers.github.resolvers.usernameMatchingUserEntityName(),
         },
       }),
+
+      // https://backstage.io/docs/auth/microsoft/easy-auth
+      easyAuth: providers.easyAuth.create({
+        signIn: {
+          resolver: async (info, ctx) => {
+            const {
+              fullProfile: { id, username },
+            } = info.result;
+
+            if (!id) {
+              throw new Error('User profile contained no id');
+            }
+
+            const userEntity = stringifyEntityRef({
+              kind: 'User',
+              name: username || id,
+              namespace: DEFAULT_NAMESPACE,
+            });
+            return ctx.issueToken({
+              claims: {
+                sub: userEntity,
+                ent: [userEntity],
+              },
+            });
+          },
+        },
+      }),
     },
   });
 }
```