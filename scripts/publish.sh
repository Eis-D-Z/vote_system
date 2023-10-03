#!/bin/bash

# check dependencies are available.
for i in jq sui; do
  if ! command -V ${i} 2>/dev/null; then
    echo "${i} is not installed"
    exit 1
  fi
done

NETWORK="https://fullnode.testnet.sui.io:443"
BACKEND_API=http://localhost:3000
FAUCET="https://faucet.testnet.sui.io/gas"

MOVE_PACKAGE_PATH=../

if [ $# -ne 0 ]; then
  if [ "$1" = "testnet" ]; then
    NETWORK="https://fullnode.testnet.sui.io:443"
    FAUCET="https://faucet.testnet.sui.io/gas"
  fi
  if [ "$1" = "devnet" ]; then
    NETWORK="https://fullnode.devnet.sui.io:443"
    FAUCET="https://faucet.devnet.sui.io/gas"
  fi
  if [ "$1" = "mainnet" ]; then
    NETWORK="https://fullnode.mainnet.sui.io:443"
  fi
fi

#faucet_res=$(curl --location --request POST "$FAUCET" --header 'Content-Type: application/json' --data-raw '{"FixedAmountRequest": { "recipient": '$ADMIN_ADDRESS'}}')

publish_res=$(sui client publish --skip-fetch-latest-git-deps --gas-budget 200000000 --skip-dependency-verification --json ${MOVE_PACKAGE_PATH})
echo "${publish_res}" >.publish.res.json

# Check if the command succeeded (exit status 0)
if [[ "$publish_res" =~ "error" ]]; then
  # If yes, print the error message and exit the script
  echo "Error during move contract publishing.  Details : $publish_res"
  exit 1
fi
echo "Contract Deployment finished!"

echo "Setting up environmental variables..."

DIGEST=$(echo "${publish_res}" | jq -r '.digest')
PACKAGE_ID=$(echo "${publish_res}" | jq -r '.effects.created[] | select(.owner == "Immutable").reference.objectId')
newObjs=$(echo "$publish_res" | jq -r '.objectChanges[] | select(.type == "created")')
ADMIN_CAP=$(echo "$newObjs" | jq -r 'select (.objectType | contains("::vote::GovernmentCensusAdmin")).objectId')


# Create a temporary file to hold the environment variables
temp_env=$(mktemp ./temp_env)


BLACKLIST=$(echo "$newObjs" | jq -r 'select (.objectType | contains("::core::Blacklist")).objectId')

ADMIN_PRIVATE_KEY=$(cat ~/.sui/sui_config/sui.keystore | jq -r '.[1]')
VOTER_PRIVATE_KEY=$(cat ~/.sui/sui_config/sui.keystore | jq -r '.[0]')

{
  echo "SUI_NETWORK=${NETWORK}"
  echo "DIGEST=${DIGEST}"
  echo "PACKAGE_ID=${PACKAGE_ID}"
  echo "ADMIN_CAP=${ADMIN_CAP}"
  echo "ADMIN_PRIVATE_KEY=${ADMIN_PRIVATE_KEY}"
  echo "VOTER_PRIVATE_KEY=${VOTER_PRIVATE_KEY}"
} > .env

# Clean up the temporary file
rm "$temp_env"

# cat >../app/.env$suffix<<-VITE_API_ENV
# VITE_SUI_NETWORK=$NETWORK
# NEXT_PUBLIC_PACKAGE=$PACKAGE_ID
# NEXT_BACKEND_API=$BACKEND_API
# VITE_API_ENV

# commented out as the POC template does not have an api directory

# cat >../api/.env$suffix<<-BACKEND_API_ENV
# SUI_NETWORK=$NETWORK
# BACKEND_API=$BACKEND_API
# PACKAGE_ADDRESS=$PACKAGE_ID
# ADMIN_ADDRESS=$ADMIN_ADDRESS
# BACKEND_API_ENV

echo "Contract Deployment finished!"