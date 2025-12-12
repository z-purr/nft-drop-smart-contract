// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721A} from "@ERC721A/contracts/ERC721A.sol";
import {IERC721A} from "@ERC721A/contracts/IERC721A.sol";
import {ERC721AQueryable} from "@ERC721A/contracts/extensions/ERC721AQueryable.sol";
import {ERC721ABurnable} from "@ERC721A/contracts/extensions/ERC721ABurnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract NFTDrop is ERC721AQueryable, ERC721ABurnable, Ownable, ERC2981, ReentrancyGuard {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    uint256 public immutable MAX_SUPPLY;
    uint256 public immutable PRICE;

    // Sale stages
    bool public saleActive = true;

    string private _baseTokenURI;
    IERC20 public immutable ACCEPTED_CURRENCY; // USDC or EURC (configurable per deployment chain)

    constructor(
        string memory name_,
        string memory symbol_,
        string memory initBaseURI,
        uint256 maxSupply_,
        uint256 price_,
        address acceptedCurrency_,
        address royaltyRecipient_,
        uint96 royaltyBps_
    ) ERC721A(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = initBaseURI;
        MAX_SUPPLY = maxSupply_;
        PRICE = price_;
        ACCEPTED_CURRENCY = IERC20(acceptedCurrency_);

        // Set default royalties (royaltyBps_ is in basis points, e.g., 500 = 5%)
        _setDefaultRoyalty(royaltyRecipient_, royaltyBps_);
    }

    // ======================
    // PUBLIC MINT (cheapest with ERC721A)
    // ======================
    function mint(uint256 quantity) external nonReentrant {
        require(saleActive, "Sale not active");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Sold out");

        uint256 totalPrice = PRICE * quantity;
        // Step 1: Receive payment from user to contract
        ACCEPTED_CURRENCY.safeTransferFrom(msg.sender, address(this), totalPrice);
        // Step 2: Automatically forward payment to owner
        ACCEPTED_CURRENCY.safeTransfer(owner(), totalPrice);

        _safeMint(msg.sender, quantity);
    }

    // ======================
    // BURN FUNCTIONALITY
    // ======================
    // burn(uint256 tokenId) is provided by ERC721ABurnable
    // Token owners can burn their NFTs to enable future "burn-to-mint" upgrade mechanics

    // ======================
    // OWNER FUNCTIONS
    // ======================
    function setSaleActive(bool _state) external onlyOwner {
        saleActive = _state;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    // ======================
    // METADATA & ERC721A OVERRIDES
    // ======================
    function _baseURI() internal view override returns (string memory) {
        return _baseTokenURI;
    }

    // Required override for ERC721A + Ownable
    function _startTokenId() internal pure override returns (uint256) {
        return 1; // starts at token ID 1
    }

    // Required override for ERC721A + ERC2981
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721A, IERC721A, ERC2981)
        returns (bool)
    {
        return ERC2981.supportsInterface(interfaceId) || ERC721A.supportsInterface(interfaceId);
    }
}
