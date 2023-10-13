// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Metadata} from "./MetadataRegistryUpgradeable.sol";
import {TerminusDID} from "./TerminusDID.sol";
import {IResolver} from "../resolvers/IResolver.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract Registrar is Context, Ownable2Step, IResolver {
    using DomainUtils for string;
    using DomainUtils for uint256;

    TerminusDID private _registry;

    address private _rootResolver;

    address private _operator;

    uint256 private constant _TAGKEY_CUSTOM_RESOLVER = 0x97;

    error Unauthorized();

    error UnsupportedTag(uint256 key);

    error BadResolver(address resolver);

    constructor(address registry_, address rootResolver_, address operator_) Ownable(_msgSender()) {
        _registry = TerminusDID(registry_);
        _rootResolver = rootResolver_;
        _operator = operator_;
    }

    function registry() public view returns (address) {
        return address(_registry);
    }

    function rootResolver() public view returns (address) {
        return _rootResolver;
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function setOperator(address operator_) public onlyOwner {
        _operator = operator_;
    }

    function setRegistry(address registry_) public onlyOwner {
        _registry = TerminusDID(registry_);
    }

    function setRootResolver(address rootResolver_) public onlyOwner {
        _rootResolver = rootResolver_;
    }

    function resolverOf(string calldata domain, uint256 key) public view returns (address) {
        if (supportsTag(key)) {
            return address(this);
        }

        uint256[] memory levels = domain.allLevels();

        address resolver = _rootResolver;
        for (uint256 i = levels.length;;) {
            if (resolver != address(0)) {
                (bool success, bool supported) = _supportsTag(resolver, key);
                if (success && supported) {
                    return resolver;
                }
            }
            if (i == 0) {
                break;
            }
            resolver = customResolver(levels[--i].tokenId());
        }

        return address(0);
    }

    function supportsTag(uint256 key) public pure returns (bool) {
        return key == _TAGKEY_CUSTOM_RESOLVER;
    }

    function customResolver(uint256 tokenId) public view returns (address) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _TAGKEY_CUSTOM_RESOLVER);
        if (exists) {
            return address(bytes20(value));
        }
        return address(0);
    }

    function setCustomResolver(string calldata domain, address resolver) public {
        uint256 tokenId = domain.tokenId();
        if (_msgSender() != _registry.ownerOf(tokenId)) {
            revert Unauthorized();
        }
        (bool success, bool supported) = _supportsTag(resolver, 0xffff);
        if (!success || supported) {
            revert BadResolver(resolver);
        }
        _registry.setTag(tokenId, _TAGKEY_CUSTOM_RESOLVER, bytes.concat(bytes20(uint160(resolver))));
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
        for (uint256 ds = domain.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
            if (ownedLevel > 0) {
                ++ownedLevel;
            } else if (_registry.ownerOf(ds.tokenId()) == owner) {
                ownedLevel = 1;
                ownedDomain = ds.toString();
            }
            ++domainLevel;
        }
    }

    function register(address tokenOwner, Metadata calldata metadata) public returns (uint256 tokenId) {
        address caller = _msgSender();
        if (caller != operator()) {
            if (!(_allowRegister(caller, metadata.domain))) {
                revert Unauthorized();
            }
        }
        return _registry.register(tokenOwner, metadata);
    }

    function setTag(string calldata domain, uint256 key, bytes calldata value) public returns (bool addedOrRemoved) {
        address caller = _msgSender();
        if (caller != operator()) {
            address resolver = resolverOf(domain, key);
            if (caller != resolver) {
                if (resolver == address(0)) {
                    revert UnsupportedTag(key);
                }
                revert Unauthorized();
            }
        }
        return _registry.setTag(domain.tokenId(), key, value);
    }

    function _allowRegister(address auth, string memory domain) internal view returns (bool) {
        for (uint256 ds = domain.parent(); !ds.isEmpty(); ds = ds.parent()) {
            if (_registry.ownerOf(ds.tokenId()) == auth) {
                return true;
            }
        }
        return false;
    }

    function _supportsTag(address resolver, uint256 key) internal view returns (bool success, bool supported) {
        bytes memory data;
        (success, data) = resolver.staticcall{gas: 30000}(abi.encodeCall(IResolver.supportsTag, (key)));
        // TODO: simplify codes when solidity supports try-decoding
        if (success && data.length >= 32 && (bytes32(data) & ~bytes32(uint256(1))) == 0) {
            supported = abi.decode(data, (bool));
        } else {
            success = false;
        }
    }
}