# NFTDrop Upgrade Testing Guide

This repository demonstrates how to **test and upgrade a UUPS
upgradeable NFTDrop contract** using **Foundry**.

The contract follows the **UUPS (Universal Upgradeable Proxy Standard)**
pattern, allowing safe upgrades while preserving existing state.

------------------------------------------------------------------------

# Overview

The **UUPS upgradeable pattern** provides:

-   **State Preservation**\
    All existing NFTs, balances, and configuration values remain
    unchanged after upgrades.

-   **Extensibility**\
    New features can be added in later versions without breaking
    previous functionality.

-   **Gas Efficiency**\
    UUPS proxies are generally more gas-efficient than other proxy
    patterns.

------------------------------------------------------------------------

# Prerequisites

Before running tests or deployments, ensure you have:

-   **Foundry installed**
-   Basic understanding of **proxy patterns**
-   A local **Ethereum RPC** (Anvil recommended)

Install Foundry if needed:

``` bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

------------------------------------------------------------------------

# Running Tests

## Run All Tests

``` bash
forge test
```

## Run Upgrade-Specific Tests

``` bash
forge test --match-contract NFTDropUpgradeTest -vvv
```

## Run Individual Upgrade Tests

``` bash
forge test --match-test test_UpgradeToV2 -vvv
forge test --match-test test_V1FunctionsStillWorkAfterUpgrade -vvv
forge test --match-test test_V2NewFeaturesWork -vvv
forge test --match-test test_StorageLayoutPreserved -vvv
```

------------------------------------------------------------------------

# Manual Upgrade Testing

## 1. Deploy V1 Contract

``` bash
export PRIVATE_KEY=your_private_key
export DEPLOY_MOCK_USDC=true
export NFT_NAME="My NFT"
export NFT_SYMBOL="MNFT"
export MAX_SUPPLY=10000
export PRICE=50000000
export ROYALTY_BPS=500
```

Deploy contract:

``` bash
forge script script/DeployNFTDrop.s.sol:DeployNFTDrop   --rpc-url http://localhost:8545   --broadcast
```

------------------------------------------------------------------------

## 2. Interact With V1

``` solidity
nftDrop.mint(5);

nftDrop.totalSupply();
nftDrop.balanceOf(user);
```

------------------------------------------------------------------------

## 3. Deploy V2 Implementation

``` solidity
NFTDropV2 v2Implementation = new NFTDropV2();
```

------------------------------------------------------------------------

## 4. Upgrade Proxy

``` solidity
nftDrop.upgradeToAndCall(address(v2Implementation), "");

NFTDropV2 nftDropV2 = NFTDropV2(payable(address(nftDrop)));

nftDropV2.initializeV2(100);
```

------------------------------------------------------------------------

## 5. Verify State Preservation

``` solidity
nftDropV2.totalSupply();
nftDropV2.balanceOf(user);
nftDropV2.MAX_SUPPLY();
nftDropV2.PRICE();
```

------------------------------------------------------------------------

## 6. Test New V2 Features

``` solidity
nftDropV2.addWhitelistedAddress(user);
nftDropV2.whitelistMint(2);
nftDropV2.getNewFeatureValue();
```

------------------------------------------------------------------------

# Upgrade Script Example

`script/UpgradeNFTDrop.s.sol`

``` solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {NFTDrop} from "../src/NFTDrop.sol";
import {NFTDropV2} from "../src/NFTDropV2.sol";

contract UpgradeNFTDrop is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address proxyAddress = vm.envAddress("PROXY_ADDRESS");

        vm.startBroadcast(deployerPrivateKey);

        NFTDropV2 v2Implementation = new NFTDropV2();

        NFTDrop proxy = NFTDrop(payable(proxyAddress));

        proxy.upgradeToAndCall(address(v2Implementation), "");

        NFTDropV2 upgraded = NFTDropV2(payable(proxyAddress));

        upgraded.initializeV2(100);

        vm.stopBroadcast();
    }
}
```

------------------------------------------------------------------------

# Running the Upgrade Script

``` bash
export PROXY_ADDRESS=0x...

forge script script/UpgradeNFTDrop.s.sol:UpgradeNFTDrop   --rpc-url $RPC_URL   --broadcast
```

------------------------------------------------------------------------

# Storage Layout Rules

⚠️ Never modify existing storage layout.

Safe changes:

-   Add variables at the end
-   Add new functions
-   Modify internal logic

Unsafe changes:

-   Reordering variables
-   Removing variables
-   Changing variable types

------------------------------------------------------------------------

# Initialization Strategy

V1:

``` solidity
initializer
```

V2:

``` solidity
reinitializer(2)
```

------------------------------------------------------------------------

# Upgrade Authorization

``` solidity
function _authorizeUpgrade(address)
    internal
    override
    onlyOwner
{}
```

------------------------------------------------------------------------

# Pre-Mainnet Upgrade Checklist

-   All tests pass
-   Upgrade tests pass
-   Storage layout validated
-   Existing state preserved
-   V1 functionality unchanged
-   V2 functionality works
-   Upgrade restricted to owner

------------------------------------------------------------------------

# Common Issues

## Initialization Reverted

Use:

    reinitializer(2)

in V2.

## Storage Collision

Always append new variables at the end.

## Functions Fail After Upgrade

Always interact with the **proxy contract address**.

------------------------------------------------------------------------

# Gas Costs

  Action          Gas
  --------------- -------------
  Upgrade         50k -- 100k
  Initialize V2   30k -- 50k
  Total           80k -- 150k

------------------------------------------------------------------------

# Security Best Practices

1.  Test on testnets
2.  Verify contracts on explorers
3.  Use multisig owner wallet
4.  Implement upgrade timelock
5.  Perform security audit

------------------------------------------------------------------------

# References

OpenZeppelin Upgradeable Contracts\
https://docs.openzeppelin.com/upgrades-plugins/1.x/

UUPS Standard\
https://eips.ethereum.org/EIPS/eip-1822

ERC1967 Proxy\
https://eips.ethereum.org/EIPS/eip-1967
