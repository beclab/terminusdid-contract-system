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
            mstore(slice, add(self, 32))
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
            result := keccak256(mload(self), mload(add(self, 32)))
        }
    }

    function parent(string memory domain) internal pure returns (Slice memory) {
        return domain.asSlice().detachSub();
    }

    function detachSub(Slice memory self) internal pure returns (Slice memory) {
        return self;
    }

    function traceLevels(string memory domain) internal pure returns (Slice[] memory) {
        return domain.asSlice().traceLevels();
    }

    function traceLevels(Slice memory self) internal pure returns (Slice[] memory levels) {
        // under construction
    }

    function isValidSubdomain(string memory subdomain) internal pure returns (bool) {
        // under construction
        return bytes(subdomain).length > 0;
    }
}
