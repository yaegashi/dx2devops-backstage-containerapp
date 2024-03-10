#!/bin/bash

set -e

npx @backstage/create-app@latest
yarn --cwd backstage/packages/backend add pg

git -C backstage init
git -C backstage add -A
git -C backstage commit -m 'First commit'
