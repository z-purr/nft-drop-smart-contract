// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "lib/forge-std/src/Test.sol";
import {NFTDrop} from "../src/NFTDrop.sol";

contract NFTDropTest is Test {
    NFTDrop drop;
    address owner = address(0x111);
    address alice = address(0x222);
    address bob = address(0x333);

    bytes32 merkleRoot = bytes32(uint256(0xabc123)); // fake root for testing
    bytes32[] proof = new bytes32[](0); // alice will be allowlisted with empty proof + fake root

    function setUp() public {
        vm.startPrank(owner);
        drop = new NFTDrop();
        drop.setMerkleRoot(merkleRoot);
        vm.stopPrank();
    }

    function test_PresaleMint() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);

        drop.setPresaleActive(true);

        // Mock allowlist: we pretend alice's leaf matches the fake root with empty proof
        vm.mockCall(
            address(drop),
            abi.encodeWithSelector(drop.isAllowlisted.selector, alice, proof),
            abi.encode(true)
        );

        drop.presaleMint{value: 0.1 ether}(2, proof);

        assertEq(drop.balanceOf(alice), 2);
        assertEq(drop.totalSupply(), 2);
        assertEq(drop.presaleMinted(alice), 2);
    }

    function test_PresaleMaxPerWallet() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        drop.setPresaleActive(true);

        vm.mockCall(address(drop), abi.encodeWithSelector(drop.isAllowlisted.selector), abi.encode(true));

        drop.presaleMint{value: 0.1 ether}(2, proof);

        vm.expectRevert("Wallet limit");
        drop.presaleMint{value: 0.05 ether}(1, proof);
    }

    function test_PublicMint10AtOnce() public {
        vm.deal(bob, 10 ether);
        vm.startPrank(owner);
        drop.setPublicSaleActive(true);
        vm.stopPrank();

        vm.startPrank(bob);
        drop.mint{value: 0.5 ether}(10);

        assertEq(drop.balanceOf(bob), 10);
        assertEq(drop.totalSupply(), 10);
    }

    function test_Withdraw() public {
        vm.deal(address(drop), 1 ether);
        uint256 ownerBalBefore = owner.balance;

        vm.prank(owner);
        drop.withdraw();

        assertEq(owner.balance, ownerBalBefore + 1 ether);
    }

    function test_Reveal() public {
        vm.prank(owner);
        drop.setBaseURI("ipfs://revealed/");

        assertEq(drop.tokenURI(1), "ipfs://revealed/1.json");
    }

    function test_CannotMintWhenSoldOut() public {
        vm.startPrank(owner);
        drop.setPublicSaleActive(true);
        // drop.airdrop(owner, 10000); // internal helper not in contract → use mint loop
        vm.stopPrank();

        // Mint exactly 10k
        for (uint i = 0; i < 1000; i++) {
            vm.prank(address(uint160(i+1000)));
            drop.mint{value: 0.5 ether}(10);
        }

        vm.expectRevert("Exceeds max");
        drop.mint{value: 0.05 ether}(1);
    }
}
