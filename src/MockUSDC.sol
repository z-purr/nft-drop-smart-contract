// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockUSDC
 * @dev Mock USDC token for testing and local deployment (6 decimals like real USDC)
 */
contract MockUSDC is ERC20 {
    constructor() ERC20("USD Coin", "USDC") {
        // Mint 1,000,000 USDC to deployer (6 decimals)
        _mint(msg.sender, 1_000_000 * 10 ** 6);
    }

    /**
     * @dev Mint tokens to any address (for testing purposes)
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @dev USDC uses 6 decimals
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
