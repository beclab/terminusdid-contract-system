// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

abstract contract TagRegistryUpgradeable is Initializable {
    struct __TagRegistry_Group {
        uint32[] keys;
        mapping(uint256 key => bytes value) values;
    }

    /// @custom:storage-location erc7201:terminus.TagRegistry
    struct __TagRegistry_Storage {
        mapping(uint256 entity => __TagRegistry_Group) _tags;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.TagRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __TagRegistry_STORAGE = 0xc8ba1573a83064b637069eac29a25dd52440bc4f98f399766e0040c151cb1f00;

    error InvalidTagKey();

    function __TagRegistry_init() internal onlyInitializing {}

    function __TagRegistry_init_unchained() internal onlyInitializing {}

    function __TagRegistry_get(uint256 entity, uint256 key) internal view returns (bool exists, bytes memory value) {
        (exists,, value) = __TagRegistry_getIn(__TagRegistry_getStorage()._tags[entity], key);
    }

    function __TagRegistry_set(uint256 entity, uint256 key, bytes memory value)
        internal
        returns (bool addedOrRemoved)
    {
        return __TagRegistry_setIn(__TagRegistry_getStorage()._tags[entity], key, value);
    }

    function __TagRegistry_count(uint256 entity) internal view returns (uint256) {
        return __TagRegistry_getStorage()._tags[entity].keys.length;
    }

    function __TagRegistry_keys(uint256 entity) internal view returns (uint256[] memory $) {
        uint32[] memory keys = __TagRegistry_getStorage()._tags[entity].keys;
        assembly {
            $ := keys
        }
    }

    function __TagRegistry_clear(uint256 entity) internal returns (uint256 count) {
        __TagRegistry_Group storage group = __TagRegistry_getStorage()._tags[entity];
        count = group.keys.length;
        for (uint256 i = 0; i < count; ++i) {
            delete group.values[group.keys[i]];
        }
        delete group.keys;
    }

    function __TagRegistry_getIn(__TagRegistry_Group storage group, uint256 key)
        private
        view
        returns (bool exists, uint16 index, bytes memory value)
    {
        value = group.values[key];
        if (value.length == 0) {
            return (false, 0, "");
        }
        exists = true;
        assembly ("memory-safe") {
            index := and(0xffff, mload(add(value, mload(value))))
            mstore(value, sub(mload(value), 2))
        }
    }

    function __TagRegistry_setIn(__TagRegistry_Group storage group, uint256 key, bytes memory value)
        private
        returns (bool addedOrRemoved)
    {
        if (key > type(uint32).max) {
            revert InvalidTagKey();
        }

        (bool exists, uint16 index,) = __TagRegistry_getIn(group, key);
        if (value.length == 0) {
            if (exists) {
                uint256 moveIndex = group.keys.length - 1;
                if (moveIndex != index) {
                    uint32 moveKey = group.keys[moveIndex];
                    group.keys[index] = moveKey;
                    bytes storage moveValue = group.values[moveKey];
                    uint256 lastByteIndex = moveValue.length - 1;
                    moveValue[lastByteIndex - 1] = bytes1(bytes2(index));
                    moveValue[lastByteIndex] = bytes1(uint8(index));
                }
                group.keys.pop();
                delete group.values[key];
                addedOrRemoved = true;
            }
            return addedOrRemoved;
        }
        if (!exists) {
            uint256 nextIndex = group.keys.length;
            assert(nextIndex <= type(uint16).max);
            index = uint16(nextIndex);
            group.keys.push(uint32(key));
            addedOrRemoved = true;
        }
        group.values[key] = bytes.concat(value, bytes2(index));
    }

    function __TagRegistry_getStorage() private pure returns (__TagRegistry_Storage storage $) {
        assembly {
            $.slot := __TagRegistry_STORAGE
        }
    }
}
