// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {ERC721AUpgradeable} from "@erc721a-upgradeable/contracts/ERC721AUpgradeable.sol";
import {IERC721AUpgradeable} from "@erc721a-upgradeable/contracts/IERC721AUpgradeable.sol";
import {
    ERC721ABurnableUpgradeable
} from "@erc721a-upgradeable/contracts/extensions/ERC721ABurnableUpgradeable.sol";
import {
    ERC2981Upgradeable
} from "@openzeppelin-contracts-upgradeable/contracts/token/common/ERC2981Upgradeable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {
    UUPSUpgradeable
} from "@openzeppelin-contracts-upgradeable/contracts/proxy/utils/UUPSUpgradeable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";

contract NFTDrop is
    ERC721AUpgradeable,
    ERC721ABurnableUpgradeable,
    OwnableUpgradeable,
    ERC2981Upgradeable,
    UUPSUpgradeable,
    ReentrancyGuard
{
    using Strings for uint256;
    using SafeERC20 for IERC20;

    // Changed from immutable to storage variables for upgradeability
    // These should only be set during initialization and never changed
    uint256 public MAX_SUPPLY;
    uint256 public PRICE;

    // Sale stages
    bool public saleActive = true;

    string private _baseTokenURI;
    IERC20 public ACCEPTED_CURRENCY; // USDC or EURC (configurable per deployment chain)

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        string memory name_,
        string memory symbol_,
        string memory initBaseURI,
        uint256 maxSupply_,
        uint256 price_,
        address acceptedCurrency_,
        address initialOwner_,
        address royaltyRecipient_,
        uint96 royaltyBps_
    ) public initializerERC721A initializer {
        // Initialize ERC721AUpgradeable
        __ERC721A_init(name_, symbol_);

        // Initialize ERC721ABurnableUpgradeable
        __ERC721ABurnable_init();

        // Initialize ERC2981Upgradeable
        __ERC2981_init();

        // Initialize OwnableUpgradeable
        __Ownable_init(initialOwner_);

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
    // NFT AS PAYMENT TOKEN FUNCTIONALITY
    // ======================
    // This NFT can be used as payment token for other contracts
    // Users approve the second contract, then second contract calls transferFrom
    // Standard ERC721 transferFrom is used - no special functions needed

    /**
     * @dev Helper function to verify user owns specific token IDs
     * @param owner The address to check ownership for
     * @param tokenIds Array of token IDs to verify
     * @return bool True if owner owns all tokens
     */
    function verifyOwnership(address owner, uint256[] calldata tokenIds)
        external
        view
        returns (bool)
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (ownerOf(tokenIds[i]) != owner) {
                return false;
            }
        }
        return true;
    }

    /**
     * @dev Get balance of specific token IDs owned by an address
     * @param owner The address to check
     * @param tokenIds Array of token IDs to check
     * @return count Number of tokens owned
     */
    function getOwnedCount(address owner, uint256[] calldata tokenIds)
        external
        view
        returns (uint256 count)
    {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            if (ownerOf(tokenIds[i]) == owner) {
                count++;
            }
        }
    }

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
        override(ERC721AUpgradeable, IERC721AUpgradeable, ERC2981Upgradeable)
        returns (bool)
    {
        return ERC2981Upgradeable.supportsInterface(interfaceId)
            || ERC721AUpgradeable.supportsInterface(interfaceId);
    }

    // ======================
    // UUPS UPGRADE AUTHORIZATION
    // ======================
    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
        // Only the owner can authorize upgrades
    }
}
