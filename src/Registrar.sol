// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {TerminusDID} from "./TerminusDID.sol";
import {Permissions} from "./Permissions.sol";
import {DomainUtils} from "./utils/DomainUtils.sol";
import {IResolver} from "./resolvers/IResolver.sol";

contract Registrar is Context, Ownable2Step {
    using DomainUtils for string;
    using DomainUtils for uint256;
    using Permissions for TerminusDID;

    TerminusDID private _registry;
    IResolver private _resolver;

    bytes8 private constant _TAGKEY_CUSTOM_RESOLVER = bytes8(uint64(0x97));

    error Unauthorized();

    error InvalidParentKind();

    error InvalidDomainString();

    error BadResolver(address resolver);

    error UnsupportedTagKey(bytes8 key);

    error InvalidTagValue(uint256 errorCode, address resolver);

    constructor(address registry_, address resolver_) {
        _registry = TerminusDID(registry_);
        _resolver = IResolver(resolver_);
    }

    function registry() public view returns (address) {
        return address(_registry);
    }

    function resolver() public view returns (address) {
        return address(_resolver);
    }

    function setRegistry(address registry_) public onlyOwner {
        _registry = TerminusDID(registry_);
    }

    function setResolver(address resolver_) public onlyOwner {
        _resolver = IResolver(resolver_);
    }

    function registerTLD(string calldata tld, address tokenOwner) public onlyOwner returns (uint256 tokenId) {
        if (!tld.isValidSubdomain()) {
            revert InvalidDomainString();
        }
        return _registry.register(tld, "", tokenOwner, TerminusDID.Kind.Organization);
    }

    function register(
        string calldata subdomain,
        string calldata parentDomain,
        string calldata did,
        address tokenOwner,
        TerminusDID.Kind kind
    ) public returns (uint256 tokenId) {
        address caller = _msgSender();
        if (!(_registry.allowRegister(caller, parentDomain) || caller == owner())) {
            revert Unauthorized();
        }
        if (_registry.getKind(parentDomain.tokenId()) != TerminusDID.Kind.Organization) {
            revert InvalidParentKind();
        }
        if (!subdomain.isValidSubdomain()) {
            revert InvalidDomainString();
        }
        return _registry.register(string.concat(subdomain, ".", parentDomain), did, tokenOwner, kind);
    }

    function setTag(string calldata domain, bytes8 key, bytes calldata value) public returns (bool addedOrRemoved) {
        uint256[] memory levels = domain.allLevels();

        address caller = _msgSender();
        if (!(caller == owner() || _registry.allowSetTag(_msgSender(), levels, key))) {
            revert Unauthorized();
        }

        address levelResolver = address(_resolver);
        for (uint256 i = levels.length;;) {
            if (levelResolver != address(0)) {
                try IResolver(levelResolver).validate(key, value) returns (uint256 status) {
                    if (status == 0) {
                        return _registry.setTag(domain.tokenId(), key, value);
                    } else if (status > 1) {
                        revert InvalidTagValue(status, levelResolver);
                    }
                } catch {
                    revert BadResolver(levelResolver);
                }
            }
            if (i == 0) {
                break;
            }
            levelResolver = _getResolver(levels[--i].tokenId());
        }

        revert UnsupportedTagKey(key);
    }

    function _getResolver(uint256 tokenId) internal view returns (address) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _TAGKEY_CUSTOM_RESOLVER);
        if (exists) {
            return address(bytes20(value));
        }
        return address(0);
    }
}
