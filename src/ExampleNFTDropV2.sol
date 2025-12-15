// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721A} from "@ERC721A/contracts/ERC721A.sol";
import {IERC721A} from "@ERC721A/contracts/IERC721A.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {NFTDrop} from "./NFTDrop.sol";

/**
 * @title ExampleNFTDropV2
 * @dev Example contract showing how to accept NFTDrop NFTs as payment tokens
 */
contract ExampleNFTDropV2 is ERC721A, Ownable, ReentrancyGuard {
    NFTDrop public paymentNFT; // The NFT contract used as payment

    uint256 public constant PRICE_PER_NFT = 1; // 1 NFTDrop token = 1 V2 NFT
    uint256 public maxSupply;
    bool public saleActive = false;

    constructor(address paymentNFT_, uint256 maxSupply_, string memory name_, string memory symbol_)
        ERC721A(name_, symbol_)
        Ownable(msg.sender)
    {
        paymentNFT = NFTDrop(paymentNFT_);
        maxSupply = maxSupply_;
    }

    /**
     * @dev Mint V2 NFTs using V1 NFTs as payment
     * @param quantity Number of V2 NFTs to mint
     * @param paymentTokenIds Array of V1 NFT token IDs to use as payment
     *
     * Requirements:
     * - Sale must be active
     * - User must own the payment tokens
     * - Must have enough payment tokens (1 V1 NFT = 1 V2 NFT)
     * - Must not exceed max supply
     */
    function mintWithNFTs(uint256 quantity, uint256[] calldata paymentTokenIds)
        external
        nonReentrant
    {
        // Fail fast checks (cheapest validations first)
        require(saleActive, "Sale not active");
        require(quantity > 0, "Quantity must be > 0");
        require(paymentTokenIds.length == quantity, "Payment tokens mismatch");

        // Check approval first to fail early if not approved (saves gas)
        require(paymentNFT.isApprovedForAll(msg.sender, address(this)), "Not approved");

        // Cache totalSupply to avoid multiple external calls
        uint256 currentSupply = totalSupply();
        require(currentSupply + quantity <= maxSupply, "Sold out");

        // Verify user owns all payment tokens
        require(paymentNFT.verifyOwnership(msg.sender, paymentTokenIds), "Not owner");

        // Burn payment NFTs directly (contract is approved operator)
        // Since contract is approved via isApprovedForAll, we can burn directly
        // This saves gas by avoiding the transfer step
        uint256 length = paymentTokenIds.length;
        for (uint256 i = 0; i < length;) {
            paymentNFT.burn(paymentTokenIds[i]);
            unchecked {
                ++i; // Safe: i < length
            }
        }

        // Mint V2 NFTs to user
        _safeMint(msg.sender, quantity);
    }

    function setSaleActive(bool _state) external onlyOwner {
        saleActive = _state;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
