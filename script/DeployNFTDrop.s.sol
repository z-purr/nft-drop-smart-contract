// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTDrop} from "../src/NFTDrop.sol";

contract DeployNFTDrop is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        string memory name = vm.envOr("NFT_NAME", string("My NFT Drop"));
        string memory symbol = vm.envOr("NFT_SYMBOL", string("MND"));
        string memory baseURI = vm.envOr("BASE_URI", string("https://api.example.com/metadata/"));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(1000));
        uint256 price = vm.envOr("PRICE", uint256(10000)); // 0.01 USDC (6 decimals)
        address currency =
            vm.envOr("CURRENCY_ADDRESS", address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913)); // Base USDC
        address royaltyRecipient = vm.envOr("ROYALTY_RECIPIENT", vm.addr(deployerPrivateKey));
        uint256 royaltyBpsUint = vm.envOr("ROYALTY_BPS", uint256(500));
        // casting to 'uint96' is safe because [explain why]
        // forge-lint: disable-next-line(unsafe-typecast)
        uint96 royaltyBps = uint96(royaltyBpsUint);

        NFTDrop nftDrop = new NFTDrop(
            name, symbol, baseURI, maxSupply, price, currency, royaltyRecipient, royaltyBps
        );

        console.log("NFTDrop deployed to:", address(nftDrop));

        vm.stopBroadcast();
    }
}
