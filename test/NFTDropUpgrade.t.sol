// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {NFTDrop} from "../src/NFTDrop.sol";
import {NFTDropV2} from "../src/NFTDropV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";

// Mock ERC20 token for testing
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

contract NFTDropUpgradeTest is Test {
    NFTDrop drop;
    NFTDropV2 dropV2;
    MockERC20 paymentToken;
    address owner = address(0x111);
    address alice = address(0x222);
    address bob = address(0x333);

    uint256 constant MAX_SUPPLY = 10000;
    uint256 constant PRICE = 50 * 10 ** 6;
    uint96 constant ROYALTY_BPS = 500;

    function setUp() public {
        vm.startPrank(owner);

        paymentToken = new MockERC20();

        // Deploy V1 implementation
        NFTDrop implementation = new NFTDrop();

        // Encode initialize function
        bytes memory initData = abi.encodeWithSelector(
            NFTDrop.initialize.selector,
            "Test NFT",
            "TNFT",
            "ipfs://test/",
            MAX_SUPPLY,
            PRICE,
            address(paymentToken),
            owner,
            owner,
            ROYALTY_BPS
        );

        // Deploy proxy
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        drop = NFTDrop(payable(address(proxy)));

        vm.stopPrank();

        paymentToken.mint(alice, 1000000 * 10 ** 6);
        paymentToken.mint(bob, 1000000 * 10 ** 6);
    }

    function test_UpgradeToV2() public {
        // Mint some NFTs before upgrade
        vm.startPrank(owner);
        drop.setSaleActive(true);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.approve(address(drop), PRICE * 5);
        drop.mint(5);
        vm.stopPrank();

        uint256 totalSupplyBefore = drop.totalSupply();
        assertEq(totalSupplyBefore, 5);
        assertEq(drop.balanceOf(bob), 5);

        // Deploy V2 implementation
        vm.startPrank(owner);
        NFTDropV2 v2Implementation = new NFTDropV2();

        // Upgrade proxy to V2
        drop.upgradeToAndCall(address(v2Implementation), "");

        // Cast proxy to V2
        dropV2 = NFTDropV2(payable(address(drop)));

        // Initialize V2 features
        dropV2.initializeV2(100);

        vm.stopPrank();

        // Verify V1 state is preserved
        assertEq(dropV2.totalSupply(), totalSupplyBefore);
        assertEq(dropV2.balanceOf(bob), 5);
        assertEq(dropV2.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(dropV2.PRICE(), PRICE);
        assertEq(dropV2.owner(), owner);

        // Verify V2 new features work
        assertEq(dropV2.getNewFeatureValue(), 100);
    }

    function test_V1FunctionsStillWorkAfterUpgrade() public {
        // Setup before upgrade
        vm.startPrank(owner);
        drop.setSaleActive(true);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.approve(address(drop), PRICE * 3);
        drop.mint(3);
        vm.stopPrank();

        // Upgrade to V2
        vm.startPrank(owner);
        NFTDropV2 v2Implementation = new NFTDropV2();
        drop.upgradeToAndCall(address(v2Implementation), "");
        dropV2 = NFTDropV2(payable(address(drop)));
        dropV2.initializeV2(200);
        vm.stopPrank();

        // Test V1 functions still work
        vm.startPrank(bob);
        paymentToken.approve(address(dropV2), PRICE * 2);
        dropV2.mint(2);
        vm.stopPrank();

        assertEq(dropV2.totalSupply(), 5);
        assertEq(dropV2.balanceOf(bob), 5);
    }

    function test_V2NewFeaturesWork() public {
        // Upgrade to V2
        vm.startPrank(owner);
        NFTDropV2 v2Implementation = new NFTDropV2();
        drop.upgradeToAndCall(address(v2Implementation), "");
        dropV2 = NFTDropV2(payable(address(drop)));
        dropV2.initializeV2(300);
        dropV2.setSaleActive(true);
        dropV2.addWhitelistedAddress(alice);
        vm.stopPrank();

        // Test new whitelist mint function
        vm.startPrank(alice);
        dropV2.whitelistMint(2);
        vm.stopPrank();

        assertEq(dropV2.totalSupply(), 2);
        assertEq(dropV2.balanceOf(alice), 2);
        assertTrue(dropV2.whitelistedAddresses(alice));

        // Non-whitelisted user cannot use whitelist mint
        vm.startPrank(bob);
        vm.expectRevert("Not whitelisted");
        dropV2.whitelistMint(1);
        vm.stopPrank();
    }

    function test_OnlyOwnerCanUpgrade() public {
        vm.startPrank(bob);
        NFTDropV2 v2Implementation = new NFTDropV2();
        vm.expectRevert();
        drop.upgradeToAndCall(address(v2Implementation), "");
        vm.stopPrank();
    }

    function test_StorageLayoutPreserved() public {
        // Mint tokens
        vm.startPrank(owner);
        drop.setSaleActive(true);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.approve(address(drop), PRICE * 10);
        drop.mint(10);
        vm.stopPrank();

        // Store some state
        uint256 supplyBefore = drop.totalSupply();
        uint256 maxSupplyBefore = drop.MAX_SUPPLY();
        uint256 priceBefore = drop.PRICE();
        address currencyBefore = address(drop.ACCEPTED_CURRENCY());
        address ownerBefore = drop.owner();

        // Upgrade
        vm.startPrank(owner);
        NFTDropV2 v2Implementation = new NFTDropV2();
        drop.upgradeToAndCall(address(v2Implementation), "");
        dropV2 = NFTDropV2(payable(address(drop)));
        dropV2.initializeV2(500);
        vm.stopPrank();

        // Verify all storage is preserved
        assertEq(dropV2.totalSupply(), supplyBefore);
        assertEq(dropV2.MAX_SUPPLY(), maxSupplyBefore);
        assertEq(dropV2.PRICE(), priceBefore);
        assertEq(address(dropV2.ACCEPTED_CURRENCY()), currencyBefore);
        assertEq(dropV2.owner(), ownerBefore);
        assertEq(dropV2.balanceOf(bob), 10);
    }

    function test_BurnStillWorksAfterUpgrade() public {
        // Mint and upgrade
        vm.startPrank(owner);
        drop.setSaleActive(true);
        NFTDropV2 v2Implementation = new NFTDropV2();
        drop.upgradeToAndCall(address(v2Implementation), "");
        dropV2 = NFTDropV2(payable(address(drop)));
        dropV2.initializeV2(100);
        vm.stopPrank();

        vm.startPrank(bob);
        paymentToken.approve(address(dropV2), PRICE);
        dropV2.mint(1);
        vm.stopPrank();

        assertEq(dropV2.balanceOf(bob), 1);
        assertEq(dropV2.totalSupply(), 1);

        // Burn after upgrade
        vm.startPrank(bob);
        dropV2.burn(1);
        vm.stopPrank();

        assertEq(dropV2.balanceOf(bob), 0);
        assertEq(dropV2.totalSupply(), 0);
    }
}
