// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ERC721A/contracts/ERC721A.sol";
import "@ERC721A/contracts/extensions/ERC721AQueryable.sol";
import "@ERC721A/contracts/extensions/ERC721ABurnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract NFTDrop is ERC721AQueryable, ERC721ABurnable, Ownable {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    uint256 public immutable maxSupply;
    uint256 public immutable price;

    // Sale stages
    bool public saleActive = false;

    string private _baseTokenURI;
    IERC20 public immutable acceptedCurrency; // USDC or EURC (configurable per deployment chain)

    constructor(
        string memory name_,
        string memory symbol_,
        string memory initBaseURI,
        uint256 maxSupply_,
        uint256 price_,
        address acceptedCurrency_
    ) ERC721A(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = initBaseURI;
        maxSupply = maxSupply_;
        price = price_;
        acceptedCurrency = IERC20(acceptedCurrency_);
    }

    // ======================
    // PUBLIC MINT (cheapest with ERC721A)
    // ======================
    function mint(uint256 quantity) external {
        require(saleActive, "Sale not active");
        require(totalSupply() + quantity <= maxSupply, "Sold out");
        
        uint256 totalPrice = price * quantity;
        // Step 1: Receive payment from user to contract
        acceptedCurrency.safeTransferFrom(msg.sender, address(this), totalPrice);
        // Step 2: Automatically forward payment to owner
        acceptedCurrency.safeTransfer(owner(), totalPrice);

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
}
