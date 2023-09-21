// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {TerminusDID} from "./TerminusDID.sol";
import {DomainUtils} from "./utils/DomainUtils.sol";

library Permissions {
    using DomainUtils for string;
    using DomainUtils for uint256;

    using {_getOwner} for TerminusDID;

    uint64 internal constant RESERVED_KEY_MAX = 0xffff;

    bytes4 private constant _sigERC721NonexistentToken = bytes4(keccak256("ERC721NonexistentToken(uint256)"));

    error NonexistentDomain();

    function allowSetTag(TerminusDID registry, address auth, uint256[] memory levels, bytes8 key)
        internal
        view
        returns (bool)
    {
        for (uint256 i = 0; i < levels.length; ++i) {
            if (registry._getOwner(levels[i].tokenId()) == auth) {
                if (i == 0) {
                    return true;
                }
                return uint64(key) <= RESERVED_KEY_MAX;
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
