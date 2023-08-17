#!/bin/bash

# Update package manager
apt-get update

# Install jq for JSON parsing
apt-get install jq -y

# Prevent any man-db trigger processing
rm /var/lib/man-db/auto-update

# Remove the Google Cloud CLI installed through snap, as it's messing with the shutdown script.
snap remove google-cloud-cli

# Add Google Cloud SDK repository and install the CLI
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee /etc/apt/sources.list.d/google-cloud-sdk.list
curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | tee /usr/share/keyrings/cloud.google.gpg
apt-get update && apt-get install google-cloud-sdk -y --no-install-recommends

# Get the secret value from Secret Manager and export it as an environment variable
export GITHUB_ORG_TOKEN=$(gcloud secrets versions access latest --secret="${secret}")

# Request a runner registration token from the GitHub API
export RUNNER_REGISTRATION_TOKEN=$(curl -s -X POST -H "authorization: token $GITHUB_ORG_TOKEN" "https://api.github.com/orgs/${github_org}/actions/runners/registration-token" | jq -r .token)

# Create necessary directories
mkdir /runner /runner-tmp

# Set working directory
cd /runner

# Download the latest runner package
curl -o actions-runner-linux-x64-2.303.0.tar.gz -L https://github.com/actions/runner/releases/download/v2.303.0/actions-runner-linux-x64-2.303.0.tar.gz

# Extract the runner installer
tar xzf ./actions-runner-linux-x64-2.303.0.tar.gz

# Create the runner and start the configuration experience
export RUNNER_ALLOW_RUNASROOT=1
./config.sh --unattended --replace --url https://github.com/${github_org} --token "$RUNNER_REGISTRATION_TOKEN"

# Start the runner
./run.sh
