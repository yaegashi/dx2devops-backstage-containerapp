/*
 * Copyright 2023 The Backstage Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  createSignInResolverFactory,
  SignInInfo,
} from '@backstage/plugin-auth-node';
import { AzureEasyAuthResult } from './types';
import { DEFAULT_NAMESPACE, stringifyEntityRef } from '@backstage/catalog-model';

/** @public */
export namespace azureEasyAuthSignInResolvers {
  export const idMatchingUserEntityAnnotation = createSignInResolverFactory({
    create() {
      return async (info: SignInInfo<AzureEasyAuthResult>, ctx) => {
        const {
          fullProfile: { id, username },
        } = info.result;

        if (!id) {
          throw new Error('User profile contained no id');
        }

        try {
          return await ctx.signInWithCatalogUser({
            annotations: {
              'graph.microsoft.com/user-id': id,
            },
          });
        } catch (e: unknown) {
          if ((e as Error)?.name !== 'NotFoundError') {
            throw e;
          }

          const userEntityRef = stringifyEntityRef({
            kind: 'User',
            name: username || id,
            namespace: DEFAULT_NAMESPACE,
          })

          return ctx.issueToken({
            claims: {
              sub: userEntityRef,
              ent: [userEntityRef],
            },
          });
        }
      };
    },
  });
}
