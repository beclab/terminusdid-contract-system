// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC5313} from "@openzeppelin/contracts/interfaces/IERC5313.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721Upgradeable} from "./ERC721Upgradeable.sol";
import {TagRegistry} from "./TagRegistry.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract TerminusDID is IERC165, ERC721Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable, TagRegistry, Multicall {
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;

    struct Metadata {
        string domain;
        string did;
        string notes;
        bool allowSubdomain;
    }

    /// @custom:storage-location erc7201:terminus.TerminusDID
    struct __TerminusDID_Storage {
        mapping(uint256 tokenId => Metadata) metadata;
        address operator;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.TerminusDID")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __TerminusDID_STORAGE = 0x4666f7c9ed2861482dc7def82e62cce78d7520c45f1fbe5cf48442a77f54bb00;

    event TransferBySuperAdmin(uint256 indexed tokenId);

    event TransferByParentOwner(uint256 indexed tokenId);

    error UnregisteredParentDomain();

    error DisallowedSubdomain();

    error InvalidDomainLabel();

    error ExistentDomain();

    error Unauthorized();

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

    function operator() public view returns (address) {
        return _getStorage().operator;
    }

    function setOperator(address operator_) public onlyOwner {
        _getStorage().operator = operator_;
    }

    function tokenURI(uint256) public pure returns (string memory) {
        return "";
    }

    function transferFrom(address from, address to, uint256 tokenId) public override {
        if (from == address(0)) {
            revert ERC721InvalidSender(address(0));
        }
        address approved = __ERC721_approved(tokenId);
        address previousOwner = __ERC721_transfer(to, tokenId);
        if (previousOwner != from) {
            revert ERC721IncorrectOwner(from, tokenId, previousOwner);
        }
        address caller = _msgSender();

        if (from == caller || __ERC721_isApprovedForAll(from, caller) || approved == caller) {
            return;
        }
        if (caller == owner()) {
            emit TransferBySuperAdmin(tokenId);
            return;
        }
        if (_isParentOwner(caller, _getStorage().metadata[tokenId].domain)) {
            emit TransferByParentOwner(tokenId);
            return;
        }
        revert ERC721InsufficientApproval(caller, tokenId);
    }

    function tokenIdOf(string calldata domain) public pure returns (uint256) {
        return domain.tokenId();
    }

    function isRegistered(string calldata domain) public view returns (bool) {
        return !_getStorage().metadata[domain.tokenId()].domain.isEmpty();
    }

    function getMetadata(uint256 tokenId) public view returns (Metadata memory) {
        __ERC721_requireOwned(tokenId);
        return _getStorage().metadata[tokenId];
    }

    /**
     * @notice Traces all levels of a domain and checks if an address is the owner of any level.
     *
     * @return domainLevel Level of `domain`.
     * @return ownedLevel  Level of the longest domain owned by `owner` in the tracing chain.
     * @return ownedDomain The longest domain owned by `owner` in the tracing chain.
     *
     * Example: `traceOwner("a.b.c", addr)` returns
     * - `(3, 2, "b.c")` if `addr` owns "b.c" but does not own "a.b.c";
     * - `(3, 0, "")` if `addr` does not own any of "a.b.c", "b.c" and "c".
     */
    function traceOwner(string calldata domain, address owner)
        public
        view
        returns (uint256 domainLevel, uint256 ownedLevel, string memory ownedDomain)
    {
        for (DomainUtils.Slice ds = domain.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
            if (ownedLevel > 0) {
                ++ownedLevel;
            } else if (ownerOf(ds.tokenId()) == owner) {
                ownedLevel = 1;
                ownedDomain = ds.toString();
            }
            ++domainLevel;
        }
    }

    function register(address tokenOwner, Metadata calldata metadata) public returns (uint256 tokenId) {
        address caller = _msgSender();
        if (!(caller == operator() || _isParentOwner(caller, metadata.domain))) {
            revert Unauthorized();
        }

        (DomainUtils.Slice label, DomainUtils.Slice parent, bool hasParent) = metadata.domain.cut();

        if (hasParent) {
            Metadata storage parentData = _getStorage().metadata[parent.tokenId()];
            if (parentData.domain.isEmpty()) {
                revert UnregisteredParentDomain();
            }
            if (!parentData.allowSubdomain) {
                revert DisallowedSubdomain();
            }
        }

        if (!label.isValidLabel()) {
            revert InvalidDomainLabel();
        }

        tokenId = metadata.domain.tokenId();
        if (!_getStorage().metadata[tokenId].domain.isEmpty()) {
            revert ExistentDomain();
        }
        _getStorage().metadata[tokenId] = metadata;

        __ERC721_mint(tokenOwner, tokenId);
    }

    function _authorizeDefineTag(string calldata domain) internal view override {
        address caller = _msgSender();
        if (domain.isEmpty() && caller == operator()) {
            return;
        }
        if (caller == ownerOf(domain.tokenId())) {
            return;
        }
        revert Unauthorized();
    }

    function _authorizeSetTag(string calldata from, string calldata to) internal view override {
        address caller = _msgSender();
        if (from.isEmpty() && caller == operator()) {
            return;
        }
        if (caller == ownerOf(from.tokenId()) && _allowSetTag(from, to)) {
            return;
        }
        revert Unauthorized();
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    function _isParentOwner(address addr, string memory domain) private view returns (bool) {
        for (DomainUtils.Slice ds = domain.parent(); !ds.isEmpty(); ds = ds.parent()) {
            if (ownerOf(ds.tokenId()) == addr) {
                return true;
            }
        }
        return false;
    }

    function _allowSetTag(string calldata from, string calldata to) private pure returns (bool) {
        for (DomainUtils.Slice ds = to.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
            if (Strings.equal(ds.toString(), from)) {
                return true;
            }
        }
        return false;
    }

    function _getStorage() private pure returns (__TerminusDID_Storage storage $) {
        assembly {
            $.slot := __TerminusDID_STORAGE
        }
    }
}
