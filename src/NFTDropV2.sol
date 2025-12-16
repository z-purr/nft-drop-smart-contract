// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {NFTDrop} from "./NFTDrop.sol";

/**
 * @title NFTDropV2
 * @dev V2 upgrade adding new features while preserving all V1 functionality
 */
contract NFTDropV2 is NFTDrop {
    // New storage variable in V2
    uint256 public newFeatureValue;
    mapping(address => bool) public whitelistedAddresses;

    // Prevent initialization of implementation contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @dev Initialize V2 - this should NOT be called if upgrading from V1
     * Only use this for fresh deployments
     */
    function initializeV2(uint256 newFeatureValue_) public reinitializer(2) {
        newFeatureValue = newFeatureValue_;
    }

    /**
     * @dev New function in V2 - add whitelisted address
     */
    function addWhitelistedAddress(address addr) external onlyOwner {
        whitelistedAddresses[addr] = true;
    }

    /**
     * @dev New function in V2 - remove whitelisted address
     */
    function removeWhitelistedAddress(address addr) external onlyOwner {
        whitelistedAddresses[addr] = false;
    }

    /**
     * @dev New function in V2 - mint with whitelist check
     */
    function whitelistMint(uint256 quantity) external nonReentrant {
        require(whitelistedAddresses[msg.sender], "Not whitelisted");
        require(saleActive, "Sale not active");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Sold out");

        // V2: Free mint for whitelisted addresses
        _safeMint(msg.sender, quantity);
    }

    /**
     * @dev New function in V2 - get new feature value
     */
    function getNewFeatureValue() external view returns (uint256) {
        return newFeatureValue;
    }
}
