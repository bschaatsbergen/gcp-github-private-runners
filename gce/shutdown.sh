#!/bin/bash

# Get the secret value from Secret Manager and export it as an environment variable
export GITHUB_ORG_TOKEN=$(gcloud secrets versions access latest --secret="${secret}")

# Request a runner removal token from the GitHub API and export it as an environment variable
export RUNNER_REMOVE_TOKEN=$(curl -s -X POST -H "authorization: token $GITHUB_ORG_TOKEN" "https://api.github.com/orgs/${github_org}/actions/runners/remove-token" | jq -r .token)

# Set working directory
cd /runner

# Remove the runner using the removal token
export RUNNER_ALLOW_RUNASROOT=1
./config.sh remove --token "$RUNNER_REMOVE_TOKEN"
