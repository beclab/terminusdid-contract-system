// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IERC165} from "@openzeppelin/contracts/interfaces/IERC165.sol";
import {IERC5313} from "@openzeppelin/contracts/interfaces/IERC5313.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {MulticallUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/MulticallUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import {ERC721Upgradeable} from "./ERC721Upgradeable.sol";
import {TagRegistry} from "./TagRegistry.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract TerminusDID is
    IERC165,
    ERC721Upgradeable,
    Ownable2StepUpgradeable,
    UUPSUpgradeable,
    TagRegistry,
    MulticallUpgradeable
{
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
        mapping(string domain => mapping(string name => address)) taggers;
        address operator;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.TerminusDID")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __TerminusDID_STORAGE = 0x4666f7c9ed2861482dc7def82e62cce78d7520c45f1fbe5cf48442a77f54bb00;

    event TransferBySuperAdmin(uint256 indexed tokenId);

    event TransferByParentOwner(uint256 indexed tokenId);

    error InvalidDomainLabel(string label);

    error UnregisteredDomain(string domain);

    error InvalidRegistration(string domain);

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
        if (caller == operator()) {
            emit TransferBySuperAdmin(tokenId);
            return;
        }
        if (_traceOwner(caller, _getStorage().metadata[tokenId].domain.parent())) {
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

    function getMetadata(string calldata domain) public view returns (Metadata memory) {
        __ERC721_requireOwned(domain.tokenId());
        return _getStorage().metadata[domain.tokenId()];
    }

    /**
     * @notice Traces all levels of a domain and checks if an address is the owner of any level.
     *
     * @return domainLevel Level of `domain`.
     * @return ownedLevel  Level of `ownedDomain` as defined below.
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
        if (!isRegistered(domain)) {
            revert UnregisteredDomain(domain);
        }
        for (DomainUtils.Slice ds = domain.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
            if (ownedLevel > 0) {
                ++ownedLevel;
            } else if (__ERC721_owner(ds.tokenId()) == owner) {
                ownedLevel = 1;
                ownedDomain = ds.toString();
            }
            ++domainLevel;
        }
    }

    function register(address tokenOwner, Metadata calldata metadata) public returns (uint256 tokenId) {
        (DomainUtils.Slice label, DomainUtils.Slice parent, bool hasParent) = metadata.domain.cut();

        if (hasParent) {
            Metadata storage parentData = _getStorage().metadata[parent.tokenId()];
            if (parentData.domain.isEmpty()) {
                revert UnregisteredDomain(parent.toString());
            }
            if (!parentData.allowSubdomain) {
                revert InvalidRegistration(metadata.domain);
            }
        }

        address caller = _msgSender();
        if (!(caller == operator() || _traceOwner(caller, parent))) {
            revert Unauthorized();
        }

        if (!label.isValidLabel()) {
            revert InvalidDomainLabel(label.toString());
        }

        tokenId = metadata.domain.tokenId();
        if (!_getStorage().metadata[tokenId].domain.isEmpty()) {
            revert InvalidRegistration(metadata.domain);
        }
        _getStorage().metadata[tokenId] = metadata;

        __ERC721_mint(tokenOwner, tokenId);
    }

    function getTagger(string calldata domain, string calldata name) public view returns (address) {
        return _getStorage().taggers[domain][name];
    }

    function setTagger(string calldata domain, string calldata name, address tagger) public {
        _authorizeDefineTag(domain);
        _getStorage().taggers[domain][name] = tagger;
    }

    function _authorizeDefineTag(string calldata domain) internal view override {
        address caller = _msgSender();
        if (domain.isEmpty() && caller == operator()) {
            return;
        }
        if (caller == __ERC721_owner(domain.tokenId())) {
            return;
        }
        revert Unauthorized();
    }

    function _authorizeSetTag(string calldata from, string calldata to, string calldata name) internal view override {
        if (!isRegistered(to)) {
            revert UnregisteredDomain(to);
        }
        if (!(_allowSetTag(from, to) && _msgSender() == _getStorage().taggers[from][name])) {
            revert Unauthorized();
        }
    }

    function _authorizeUpgrade(address newImplementation) internal view override onlyOwner {}

    function _traceOwner(address addr, DomainUtils.Slice ds) private view returns (bool) {
        for (; !ds.isEmpty(); ds = ds.parent()) {
            if (__ERC721_owner(ds.tokenId()) == addr) {
                return true;
            }
        }
        return false;
    }

    function _allowSetTag(string calldata from, string calldata to) private pure returns (bool) {
        if (from.isEmpty()) {
            return true;
        }
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
