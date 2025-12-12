// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@ERC721A/contracts/ERC721A.sol";
import "@ERC721A/contracts/extensions/ERC721AQueryable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract NFTDrop is ERC721AQueryable, Ownable {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant PRICE = 0.05 ether;

    // Sale stages
    bool public presaleActive = false;
    bool public publicSaleActive = false;

    string private _baseTokenURI;
    bytes32 public merkleRoot;

    // Presale tracking (per wallet)
    mapping(address => uint256) public presaleMinted;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory initBaseURI
    ) ERC721A(name_, symbol_) Ownable(msg.sender) {
        _baseTokenURI = initBaseURI;
    }

    // ======================
    // PUBLIC MINT (cheapest with ERC721A)
    // ======================
    function mint(uint256 quantity) external payable {
        require(publicSaleActive, "Public sale not active");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Sold out");
        require(msg.value >= PRICE * quantity, "Not enough ETH");

        _safeMint(msg.sender, quantity);
    }

    // ======================
    // PRESALE / ALLOWLIST MINT
    // ======================
    function presaleMint(uint256 quantity, bytes32[] calldata proof) external payable {
        require(presaleActive, "Presale not active");
        require(isAllowlisted(msg.sender, proof), "Not on allowlist");
        require(totalSupply() + quantity <= MAX_SUPPLY, "Sold out");
        require(presaleMinted[msg.sender] + quantity <= 2, "Exceeds presale limit"); // change if needed
        require(msg.value >= PRICE * quantity, "Not enough ETH");

        presaleMinted[msg.sender] += quantity;

        _safeMint(msg.sender, quantity);
    }

    function isAllowlisted(address addr, bytes32[] calldata proof) public view returns (bool) {
        bytes32 leaf = keccak256(abi.encodePacked(addr));
        return MerkleProof.verify(proof, merkleRoot, leaf);
    }

    // ======================
    // OWNER FUNCTIONS
    // ======================
    function setPresaleActive(bool _state) external onlyOwner {
        presaleActive = _state;
    }

    function setPublicSaleActive(bool _state) external onlyOwner {
        publicSaleActive = _state;
    }

    function setMerkleRoot(bytes32 _root) external onlyOwner {
        merkleRoot = _root;
    }

    function setBaseURI(string calldata uri) external onlyOwner {
        _baseTokenURI = uri;
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
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