// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

library DomainUtils {
    using {asSlice} for string;
    using DomainUtils for Slice;

    struct Slice {
        uint256 ptr;
        uint256 len;
    }

    function asSlice(string memory self) internal pure returns (Slice memory) {
        Slice memory slice = Slice(0, bytes(self).length);
        assembly {
            mstore(slice, add(32, self))
        }
        return slice;
    }

    function clone(Slice memory self) internal pure returns (Slice memory) {
        return Slice(self.ptr, self.len);
    }

    function isEmpty(Slice memory self) internal pure returns (bool) {
        return self.len == 0;
    }

    function tokenId(string memory domain) internal pure returns (uint256) {
        return uint256(keccak256(bytes(domain)));
    }

    function tokenId(Slice memory self) internal pure returns (uint256 result) {
        assembly {
            result := keccak256(mload(self), mload(add(32, self)))
        }
    }

    function parent(string memory domain) internal pure returns (Slice memory) {
        return domain.asSlice().detachSub();
    }

    function detachSub(Slice memory self) internal pure returns (Slice memory) {
        assembly ("memory-safe") {
            for {
                let ptr := mload(self)
                let end := add(ptr, mload(add(32, self)))
            } lt(ptr, end) { ptr := add(1, ptr) } {
                if eq(shr(248, mload(ptr)), 0x2e) {
                    ptr := add(1, ptr)
                    mstore(self, ptr)
                    mstore(add(32, self), sub(end, ptr))
                    break
                }
            }
        }
        return self;
    }

    function traceLevels(string memory domain) internal pure returns (Slice[] memory) {
        return domain.asSlice().traceLevels();
    }

    function traceLevels(Slice memory self) internal pure returns (Slice[] memory levels) {
        assembly ("memory-safe") {
            levels := mload(0x40)
            let cursor := add(32, levels)
            for {
                let ptr := mload(self)
                mstore(cursor, ptr)
                let len := mload(add(32, self))
                mstore(add(32, cursor), len)
                let end := sub(add(ptr, len), 1)
                cursor := add(64, cursor)
            } lt(ptr, end) { ptr := add(1, ptr) } {
                if eq(shr(248, mload(ptr)), 0x2e) {
                    mstore(cursor, add(1, ptr))
                    mstore(add(32, cursor), sub(end, ptr))
                    cursor := add(64, cursor)
                }
            }
            mstore(levels, shr(6, sub(cursor, levels)))
            mstore(0x40, cursor)
        }
    }

    function isValidSubdomain(string memory subdomain) internal pure returns (bool) {
        // under construction
        return bytes(subdomain).length > 0;
    }
}
