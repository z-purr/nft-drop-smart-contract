// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {NFTDrop} from "../src/NFTDrop.sol";
import {MockUSDC} from "../src/MockUSDC.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployNFTDrop is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy MockUSDC if DEPLOY_MOCK_USDC is set to true, otherwise use provided address
        address currency;
        bool deployMockUSDC = vm.envOr("DEPLOY_MOCK_USDC", false);

        if (deployMockUSDC) {
            MockUSDC mockUSDC = new MockUSDC();
            currency = address(mockUSDC);
            console.log("MockUSDC deployed to:", currency);
            console.log(
                "MockUSDC balance:",
                mockUSDC.balanceOf(deployer) / 10 ** 6,
                "USDC"
            );
        } else {
            currency = vm.envOr(
                "CURRENCY_ADDRESS",
                address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913) // Base USDC default
            );
            console.log("Using currency at:", currency);
        }

        string memory name = vm.envOr("NFT_NAME", string("My NFT Drop"));
        string memory symbol = vm.envOr("NFT_SYMBOL", string("MND"));
        string memory baseURI = vm.envOr("BASE_URI", string("https://api.example.com/metadata/"));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", uint256(1000));
        uint256 price = vm.envOr("PRICE", uint256(50 * 10 ** 6)); // 50 USDC (6 decimals)
        address initialOwner = vm.envOr("INITIAL_OWNER", deployer);
        address royaltyRecipient = vm.envOr("ROYALTY_RECIPIENT", deployer);
        uint256 royaltyBpsUint = vm.envOr("ROYALTY_BPS", uint256(500));
        // casting to 'uint96' is safe because royaltyBps is always < 10000 (100%)
        // forge-lint: disable-next-line(unsafe-typecast)
        uint96 royaltyBps = uint96(royaltyBpsUint);

        // Step 1: Deploy Implementation Contract
        console.log("Deploying implementation contract...");
        NFTDrop implementation = new NFTDrop();
        console.log("Implementation deployed to:", address(implementation));

        // Step 2: Encode initialize function call
        bytes memory initData = abi.encodeWithSelector(
            NFTDrop.initialize.selector,
            name,
            symbol,
            baseURI,
            maxSupply,
            price,
            currency,
            initialOwner,
            royaltyRecipient,
            royaltyBps
        );

        // Step 3: Deploy Proxy Contract
        console.log("Deploying proxy contract...");
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);
        console.log("Proxy deployed to:", address(proxy));

        // Step 4: Get proxy instance
        NFTDrop nftDrop = NFTDrop(payable(address(proxy)));

        // Log important addresses for verification
        console.log("========================================");
        console.log("DEPLOYMENT SUMMARY");
        console.log("========================================");
        console.log("Implementation Address:", address(implementation));
        console.log("Proxy Address:", address(proxy));
        console.log("Initial Owner:", initialOwner);
        console.log("Max Supply:", maxSupply);
        console.log("Price:", price / 10 ** 6, "USDC");
        console.log("Royalty:", royaltyBps, "bps (", royaltyBps / 100, "%)");
        console.log("========================================");
        console.log("");
        console.log("To verify on BSCScan:");
        console.log("1. Verify implementation:", address(implementation));
        console.log("2. Verify proxy:", address(proxy), "with implementation:", address(implementation));

        vm.stopBroadcast();
    }
}
