// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {NFTDrop} from "../src/NFTDrop.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// Mock ERC20 token for testing (6 decimals like USDC/EURC)
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {
        _mint(msg.sender, 1000000 * 10 ** 6);
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}

contract NFTDropTest is Test {
    NFTDrop drop;
    MockERC20 paymentToken;
    address owner = address(0x111);
    address alice = address(0x222);
    address bob = address(0x333);

    uint256 constant MAX_SUPPLY = 10000;
    uint256 constant PRICE = 50 * 10 ** 6; // 50 tokens with 6 decimals
    uint96 constant ROYALTY_BPS = 500; // 5%

    function setUp() public {
        vm.startPrank(owner);

        // Deploy mock ERC20 token
        paymentToken = new MockERC20();

        // Deploy NFTDrop contract
        drop = new NFTDrop(
            "Test NFT",
            "TNFT",
            "ipfs://test/",
            MAX_SUPPLY,
            PRICE,
            address(paymentToken),
            owner, // royalty recipient
            ROYALTY_BPS // 5% royalty
        );

        vm.stopPrank();

        // Give tokens to test users
        paymentToken.mint(alice, 1000000 * 10 ** 6);
        paymentToken.mint(bob, 1000000 * 10 ** 6);
    }

    function test_PublicMint10AtOnce() public {
        vm.startPrank(owner);
        drop.setSaleActive(true);
        vm.stopPrank();

        uint256 quantity = 10;
        uint256 totalPrice = PRICE * quantity;

        vm.startPrank(bob);
        paymentToken.approve(address(drop), totalPrice);
        drop.mint(quantity);
        vm.stopPrank();

        assertEq(drop.balanceOf(bob), quantity);
        assertEq(drop.totalSupply(), quantity);
    }

    function test_Reveal() public {
        vm.startPrank(owner);
        drop.setSaleActive(true);
        drop.setBaseURI("ipfs://revealed/");
        vm.stopPrank();

        // Mint a token first
        vm.startPrank(bob);
        paymentToken.approve(address(drop), PRICE);
        drop.mint(1);
        vm.stopPrank();

        assertEq(drop.tokenURI(1), "ipfs://revealed/1");
    }

    function test_CannotMintWhenSoldOut() public {
        vm.startPrank(owner);
        drop.setSaleActive(true);
        vm.stopPrank();

        // Mint exactly maxSupply tokens (using batch minting to save gas)
        paymentToken.mint(bob, PRICE * MAX_SUPPLY);
        vm.startPrank(bob);
        paymentToken.approve(address(drop), PRICE * MAX_SUPPLY);

        // Mint all tokens in one batch (most gas efficient)
        drop.mint(MAX_SUPPLY);

        // Verify we've minted all tokens
        assertEq(drop.totalSupply(), MAX_SUPPLY);

        // Try to mint one more - should fail with "Sold out"
        paymentToken.mint(bob, PRICE);
        paymentToken.approve(address(drop), PRICE);
        vm.expectRevert("Sold out");
        drop.mint(1);
        vm.stopPrank();
    }
}
