// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {Metadata} from "./MetadataRegistryUpgradeable.sol";
import {TerminusDID} from "./TerminusDID.sol";
import {IResolver} from "../resolvers/IResolver.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract Registrar is Context, Ownable2Step {
    using DomainUtils for string;
    using DomainUtils for uint256;
    using Permissions for TerminusDID;

    TerminusDID private _registry;
    IResolver private _resolver;

    address private _operator;

    uint256 private constant _TAGKEY_CUSTOM_RESOLVER = 0x97;

    error Unauthorized();

    error BadResolver(address resolver);

    error UnsupportedTagKey(uint256 key);

    error InvalidTagValue(uint256 errorCode, address resolver);

    constructor(address registry_, address resolver_, address operator_) Ownable(_msgSender()) {
        _registry = TerminusDID(registry_);
        _resolver = IResolver(resolver_);
        _operator = operator_;
    }

    function operator() public view returns (address) {
        return _operator;
    }

    function registry() public view returns (address) {
        return address(_registry);
    }

    function resolver() public view returns (address) {
        return address(_resolver);
    }

    function setOperator(address operator_) public onlyOwner {
        _operator = operator_;
    }

    function setRegistry(address registry_) public onlyOwner {
        _registry = TerminusDID(registry_);
    }

    function setResolver(address resolver_) public onlyOwner {
        _resolver = IResolver(resolver_);
    }

    function register(address tokenOwner, Metadata calldata metadata) public returns (uint256 tokenId) {
        address caller = _msgSender();
        if (caller != operator()) {
            string memory parentDomain = metadata.domain.parent().toString();
            if (!(_registry.allowRegister(caller, parentDomain))) {
                revert Unauthorized();
            }
        }
        return _registry.register(tokenOwner, metadata);
    }

    function setTag(string calldata domain, uint256 key, bytes calldata value) public returns (bool addedOrRemoved) {
        uint256[] memory levels = domain.allLevels();

        address caller = _msgSender();
        if (!(caller == operator() || _registry.allowSetTag(caller, levels, key))) {
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

library Permissions {
    using DomainUtils for string;
    using DomainUtils for uint256;

    using {_getOwner} for TerminusDID;

    uint256 internal constant RESERVED_KEY_MAX = 0xffff;

    bytes4 private constant _sigERC721NonexistentToken = bytes4(keccak256("ERC721NonexistentToken(uint256)"));

    error NonexistentDomain();

    function allowSetTag(TerminusDID registry, address auth, uint256[] memory levels, uint256 key)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < levels.length; ++i) {
            if (registry._getOwner(levels[i].tokenId()) == auth) {
                if (i == 0) {
                    return true;
                }
                return key <= RESERVED_KEY_MAX;
            }
        }
        return false;
    }

    function allowRegister(TerminusDID registry, address auth, string memory domain) internal view returns (bool) {
        for (uint256 ds = domain.asSlice(); !ds.isEmpty(); ds = ds.parent()) {
            if (registry._getOwner(ds.tokenId()) == auth) {
                return true;
            }
        }
        return false;
    }

    function _getOwner(TerminusDID registry, uint256 tokenId) private view returns (address) {
        try registry.ownerOf(tokenId) returns (address owner) {
            return owner;
        } catch (bytes memory reason) {
            if (reason.length == 36 && bytes4(reason) == _sigERC721NonexistentToken) {
                revert NonexistentDomain();
            } else {
                assembly {
                    revert(add(32, reason), mload(reason))
                }
            }
        }
    }
}
