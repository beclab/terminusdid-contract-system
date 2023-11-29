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
    using DomainUtils for DomainUtils.Slice;

    TerminusDID private _registry;

    address private _rootResolver;

    address private _operator;

    uint256 private constant _TAGKEY_CUSTOM_RESOLVER = 0x97;

    error Unauthorized();

    error UnsupportedTag(uint256 tokenId, uint256 key);

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

    function getterOf(string calldata domain, uint256 key) public view returns (function(uint256) external view $) {
        (address resolver, bytes4 getter) = _traceResolver(domain, key);
        if (resolver == address(0)) {
            revert UnsupportedTag(domain.tokenId(), key);
        }
        assembly {
            $.address := resolver
            $.selector := shr(224, getter)
        }
    }

    function resolverOf(string calldata domain, uint256 key) public view returns (address) {
        (address resolver,) = _traceResolver(domain, key);
        if (resolver == address(0)) {
            revert UnsupportedTag(domain.tokenId(), key);
        }
        return resolver;
    }

    function tagGetter(uint256 key) public pure returns (bytes4) {
        if (key == _TAGKEY_CUSTOM_RESOLVER) {
            return this.customResolver.selector;
        }
        return 0;
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
        (bool success, bytes4 getter) = _tagGetter(resolver, 0xffff);
        if (!success || getter != 0) {
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
        for (DomainUtils.Slice ds = domain.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
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
        if (caller == operator()) {
            string memory parent = metadata.domain.parent().toString();
            if (!parent.isEmpty() && parent.parent().isEmpty() && !_registry.isRegistered(parent)) {
                _registry.register(
                    address(0xdead), Metadata({domain: parent, did: "", notes: "", allowSubdomain: true})
                );
            }
        } else if (!(_allowRegister(caller, metadata.domain))) {
            revert Unauthorized();
        }
        return _registry.register(tokenOwner, metadata);
    }

    function setTag(string calldata domain, uint256 key, bytes calldata value) public returns (bool addedOrRemoved) {
        uint256 tokenId = domain.tokenId();
        addedOrRemoved = _registry.setTag(tokenId, key, value);

        address caller = _msgSender();
        if (caller != operator()) {
            function(uint256) external view getter = getterOf(domain, key);
            (address resolver, bytes4 selector) = (getter.address, getter.selector);

            if (caller != resolver) {
                revert Unauthorized();
            }

            bool ok;
            uint256 outputSize;
            assembly {
                let input := mload(0x40)
                mstore(input, selector)
                mstore(add(4, input), tokenId)
                ok := staticcall(gas(), resolver, input, 36, 0, 0)
                outputSize := returndatasize()
            }
            if (!(ok && outputSize >= 32)) {
                revert BadResolver(resolver);
            }
        }
    }

    function _traceResolver(string calldata domain, uint256 key) internal view returns (address ca, bytes4 getter) {
        getter = tagGetter(key);
        if (getter != 0) {
            return (address(this), getter);
        }

        DomainUtils.Slice[] memory levels = domain.allLevels();

        address resolver = _rootResolver;
        for (uint256 i = levels.length;;) {
            if (resolver != address(0)) {
                bool success;
                (success, getter) = _tagGetter(resolver, key);
                if (success && getter != 0) {
                    ca = resolver;
                    break;
                }
            }
            if (i == 0) {
                break;
            }
            resolver = customResolver(levels[--i].tokenId());
        }
    }

    function _allowRegister(address auth, string memory domain) internal view returns (bool) {
        for (DomainUtils.Slice ds = domain.parent(); !ds.isEmpty(); ds = ds.parent()) {
            if (_registry.ownerOf(ds.tokenId()) == auth) {
                return true;
            }
        }
        return false;
    }

    function _tagGetter(address resolver, uint256 key) internal view returns (bool success, bytes4 getter) {
        bytes memory data;
        (success, data) = resolver.staticcall{gas: 30000}(abi.encodeCall(IResolver.tagGetter, (key)));
        // TODO: simplify codes when solidity supports try-decoding
        if (success && data.length >= 32 && (bytes32(data) & (~bytes32(uint256(1))) >> 32) == 0) {
            getter = abi.decode(data, (bytes4));
        } else {
            success = false;
        }
    }
}
