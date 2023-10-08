// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC5313} from "@openzeppelin/contracts/interfaces/IERC5313.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721Upgradeable} from "./ERC721Upgradeable.sol";
import {Metadata, MetadataRegistryUpgradeable} from "./MetadataRegistryUpgradeable.sol";
import {TagRegistryUpgradeable} from "./TagRegistryUpgradeable.sol";

contract TerminusDID is
    IERC165,
    ERC721Upgradeable,
    MetadataRegistryUpgradeable,
    TagRegistryUpgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable
{
    address private _registrar;

    error UnauthorizedRegistrar(address);

    modifier onlyRegistrar() {
        if (_msgSender() != _registrar) {
            revert UnauthorizedRegistrar(_msgSender());
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(string memory name_, string memory symbol_) external initializer {
        __ERC721_init_unchained(name_, symbol_);
        __Ownable_init_unchained(_msgSender());
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721Upgradeable, IERC165) returns (bool) {
        return interfaceId == type(IERC5313).interfaceId || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId) public view returns (string memory) {
        return __MetadataRegistry_get(tokenId).did;
    }

    function registrar() public view returns (address) {
        return _registrar;
    }

    function setRegistrar(address newRegistrar) public onlyOwner {
        _registrar = newRegistrar;
    }

    function tokenIdOf(string calldata domain) public pure returns (uint256) {
        return __MetadataRegistry_id(domain);
    }

    function isRegistered(string calldata domain) public view returns (bool) {
        return __MetadataRegistry_registered(domain);
    }

    function getMetadata(uint256 tokenId) public view returns (Metadata memory) {
        __ERC721_requireOwned(tokenId);
        return __MetadataRegistry_get(tokenId);
    }

    function getTagValue(uint256 tokenId, uint256 key) public view returns (bool exists, bytes memory value) {
        __ERC721_requireOwned(tokenId);
        return __TagRegistry_get(tokenId, key);
    }

    function getTagCount(uint256 tokenId) public view returns (uint256) {
        __ERC721_requireOwned(tokenId);
        return __TagRegistry_count(tokenId);
    }

    function getTagKeys(uint256 tokenId) public view returns (uint256[] memory) {
        __ERC721_requireOwned(tokenId);
        return __TagRegistry_keys(tokenId);
    }

    function setTag(uint256 tokenId, uint256 key, bytes calldata value)
        public
        onlyRegistrar
        returns (bool addedOrRemoved)
    {
        __ERC721_requireOwned(tokenId);
        return __TagRegistry_set(tokenId, key, value);
    }

    function register(address tokenOwner, Metadata calldata metadata) public onlyRegistrar returns (uint256 tokenId) {
        tokenId = __MetadataRegistry_register(metadata);
        __ERC721_mint(tokenOwner, tokenId);
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}
}
