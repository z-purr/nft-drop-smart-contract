# NFTDrop Upgrade Testing Guide

This guide explains how to test the UUPS upgradeable NFTDrop contract.

## Overview

The NFTDrop contract uses UUPS (Universal Upgradeable Proxy Standard) pattern, allowing:
- **Preservation of state**: All existing NFTs, balances, and settings remain intact
- **Adding new features**: New functions can be added in V2 without breaking V1 functionality
- **Gas efficiency**: UUPS is more gas-efficient than other proxy patterns

## Prerequisites

- Foundry installed
- Understanding of proxy patterns (UUPS)

## Testing Upgrades Locally

### 1. Run Existing Tests

First, ensure all existing tests pass:

```bash
forge test
```

### 2. Run Upgrade-Specific Tests

Run the upgrade test suite:

```bash
forge test --match-contract NFTDropUpgradeTest -vvv
```

### 3. Test Individual Upgrade Scenarios

```bash
# Test basic upgrade
forge test --match-test test_UpgradeToV2 -vvv

# Test V1 functions still work
forge test --match-test test_V1FunctionsStillWorkAfterUpgrade -vvv

# Test new V2 features
forge test --match-test test_V2NewFeaturesWork -vvv

# Test storage preservation
forge test --match-test test_StorageLayoutPreserved -vvv
```

## Manual Testing Steps

### Step 1: Deploy V1 Contract

```bash
# Set your environment variables
export PRIVATE_KEY=your_private_key
export DEPLOY_MOCK_USDC=true
export NFT_NAME="My NFT"
export NFT_SYMBOL="MNFT"
export MAX_SUPPLY=10000
export PRICE=50000000  # 50 USDC (6 decimals)
export ROYALTY_BPS=500  # 5%

# Deploy V1
forge script script/DeployNFTDrop.s.sol:DeployNFTDrop \
  --rpc-url http://localhost:8545 \
  --broadcast
```

### Step 2: Interact with V1

```solidity
// Mint some NFTs
nftDrop.mint(5);

// Check state
nftDrop.totalSupply(); // Should be 5
nftDrop.balanceOf(user); // Should be 5
```

### Step 3: Deploy V2 Implementation

```solidity
// In a script or test
NFTDropV2 v2Implementation = new NFTDropV2();
```

### Step 4: Upgrade Proxy

```solidity
// As owner
nftDrop.upgradeToAndCall(address(v2Implementation), "");

// Cast to V2
NFTDropV2 nftDropV2 = NFTDropV2(payable(address(nftDrop)));

// Initialize V2 features
nftDropV2.initializeV2(100);
```

### Step 5: Verify State Preservation

```solidity
// All V1 state should be preserved
nftDropV2.totalSupply(); // Still 5
nftDropV2.balanceOf(user); // Still 5
nftDropV2.MAX_SUPPLY(); // Unchanged
nftDropV2.PRICE(); // Unchanged
```

### Step 6: Test New V2 Features

```solidity
// New V2 functions
nftDropV2.addWhitelistedAddress(user);
nftDropV2.whitelistMint(2); // Free mint for whitelisted
nftDropV2.getNewFeatureValue(); // Returns 100
```

## Upgrade Script Example

Create `script/UpgradeNFTDrop.s.sol`:

```solidity
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
        
        // Deploy V2 implementation
        NFTDropV2 v2Implementation = new NFTDropV2();
        
        // Get proxy instance
        NFTDrop proxy = NFTDrop(payable(proxyAddress));
        
        // Upgrade
        proxy.upgradeToAndCall(address(v2Implementation), "");
        
        // Cast to V2
        NFTDropV2 upgraded = NFTDropV2(payable(proxyAddress));
        
        // Initialize V2 (if needed)
        upgraded.initializeV2(100);
        
        console.log("Upgraded to V2 at:", address(v2Implementation));
        console.log("Proxy address:", proxyAddress);
        
        vm.stopBroadcast();
    }
}
```

Run upgrade:

```bash
export PROXY_ADDRESS=0x... # Your proxy address
forge script script/UpgradeNFTDrop.s.sol:UpgradeNFTDrop \
  --rpc-url $RPC_URL \
  --broadcast
```

## Important Considerations

### 1. Storage Layout

⚠️ **CRITICAL**: Never change the order or types of existing storage variables in upgrades!

**Safe:**
- Adding new variables at the end
- Adding new functions
- Modifying function logic

**Unsafe:**
- Changing variable types
- Reordering variables
- Removing variables

### 2. Initialization

- V1 uses `initialize()` with `initializer` modifier
- V2 uses `initializeV2()` with `reinitializer(2)` modifier
- This prevents double initialization

### 3. Authorization

Only the owner can upgrade:

```solidity
function _authorizeUpgrade(address) internal override onlyOwner {
    // Only owner can upgrade
}
```

### 4. Testing Checklist

Before upgrading on mainnet:

- [ ] All existing tests pass
- [ ] Upgrade tests pass
- [ ] State is preserved (supply, balances, settings)
- [ ] V1 functions still work
- [ ] V2 new features work
- [ ] Only owner can upgrade
- [ ] Storage layout is correct
- [ ] Gas costs are acceptable

## Common Issues

### Issue: "Initialization reverted"

**Solution**: Make sure you're using `reinitializer(2)` in V2, not `initializer`.

### Issue: Storage collision

**Solution**: Always add new storage variables at the end, never modify existing ones.

### Issue: Functions don't work after upgrade

**Solution**: Ensure you're calling functions on the proxy address, not the implementation.

## Gas Costs

- Upgrade transaction: ~50,000 - 100,000 gas
- Initialize V2: ~30,000 - 50,000 gas
- Total upgrade cost: ~80,000 - 150,000 gas

## Security Best Practices

1. **Test thoroughly** on testnets before mainnet
2. **Verify implementation** contract on Etherscan
3. **Use timelock** for production upgrades (recommended)
4. **Multi-sig** for owner wallet
5. **Audit** upgrade logic before deploying

## Resources

- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/upgrades-plugins/1.x/)
- [UUPS Pattern](https://eips.ethereum.org/EIPS/eip-1822)
- [ERC1967 Proxy](https://eips.ethereum.org/EIPS/eip-1967)
