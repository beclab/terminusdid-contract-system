// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {ABI} from "../utils/ABI.sol";
import {Tag} from "../utils/Tag.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";
import {OffchainValues} from "../utils/OffchainValues.sol";

abstract contract TagRegistry {
    using ABI for ABI.Var;
    using ABI for ABI.ReflectVar;
    using Tag for Tag.Group;
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;
    using OffchainValues for OffchainValues.Register;

    struct TagType {
        bytes abiType;
        bytes32 fieldNamesHash;
    }

    /// @custom:storage-location erc7201:terminus.TagRegistry
    struct __TagRegistry_Storage {
        mapping(string domain => mapping(string name => TagType)) types;
        mapping(string from => mapping(string to => Tag.Group)) tags;
        OffchainValues.Register fieldNames;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.TagRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __TagRegistry_STORAGE = 0xc8ba1573a83064b637069eac29a25dd52440bc4f98f399766e0040c151cb1f00;

    error UndefinedTag(string domain, string name);

    error RedefinedTag(string domain, string name);

    error InvalidTagDefinition();

    function addTag(string calldata from, string calldata to, string calldata name, bytes calldata value) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        bytes memory abiType = $.types[from][name].abiType;
        if (abiType.length == 0) {
            revert UndefinedTag(from, name);
        }
        $.tags[from][to].add(name).bind(abiType).set(value);
    }

    function removeTag(string calldata from, string calldata to, string calldata name) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        $.tags[from][to].remove(name);
    }

    function getTagElem(string calldata from, string calldata to, string calldata name, uint256[] calldata elemPath)
        public
        view
        returns (bytes memory)
    {
        return __TagRegistry_getReflectVar(from, to, name, elemPath).get();
    }

    function updateTagElem(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath,
        bytes calldata value
    ) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).set(value);
    }

    function getTagElemLength(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath
    ) public view returns (uint256) {
        return __TagRegistry_getReflectVar(from, to, name, elemPath).length();
    }

    function pushTagElem(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath,
        bytes calldata value
    ) public {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).push(value);
    }

    function popTagElem(string calldata from, string calldata to, string calldata name, uint256[] calldata elemPath)
        public
    {
        _authorizeSetTag(from, to, name);
        __TagRegistry_getReflectVar(from, to, name, elemPath).pop();
    }

    function getTagCount(string calldata from, string calldata to) public view returns (uint256) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        return $.tags[from][to].count();
    }

    function getTagNameByIndex(string calldata from, string calldata to, uint256 index)
        public
        view
        returns (string memory)
    {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        (string memory name,) = $.tags[from][to].getAt(index);
        return name;
    }

    function getTagType(string calldata domain, string calldata name)
        public
        view
        returns (bytes memory abiType, bytes32 fieldNamesHash)
    {
        TagType storage $ = __TagRegistry_getStorage().types[domain][name];
        if ($.abiType.length == 0) {
            revert UndefinedTag(domain, name);
        }
        return ($.abiType, $.fieldNamesHash);
    }

    function getFieldNamesEventBlock(string calldata domain, string calldata name) public view returns (uint256) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        TagType storage tagType = $.types[domain][name];
        if (tagType.abiType.length == 0) {
            revert UndefinedTag(domain, name);
        }
        return $.fieldNames.eventBlockNumber(tagType.fieldNamesHash);
    }

    function defineTag(
        string calldata domain,
        string calldata name,
        bytes calldata abiType,
        string[] calldata fieldNames
    ) public {
        _authorizeDefineTag(domain);
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        TagType storage tagType = $.types[domain][name];
        if (tagType.abiType.length > 0) {
            revert RedefinedTag(domain, name);
        }
        if (!__TagRegistry_isValidName(name) || abiType.length > 31) {
            revert InvalidTagDefinition();
        }
        ABI.validateType(abiType);
        if (ABI.totalTupleFields(abiType) != fieldNames.length) {
            revert InvalidTagDefinition();
        }
        for (uint256 i = 0; i < fieldNames.length; ++i) {
            if (!__TagRegistry_isValidName(fieldNames[i])) {
                revert InvalidTagDefinition();
            }
        }
        (bytes32 fieldNamesHash,) = $.fieldNames.add(fieldNames);
        tagType.abiType = abiType;
        tagType.fieldNamesHash = fieldNamesHash;
    }

    function _authorizeDefineTag(string calldata domain) internal virtual;

    function _authorizeSetTag(string calldata from, string calldata to, string calldata name) internal virtual;

    function __TagRegistry_isValidName(string memory fieldName) private pure returns (bool) {
        uint256 len = bytes(fieldName).length;
        if (len == 0 || len > 31) {
            return false;
        }
        bytes32 s;
        assembly {
            s := mload(add(32, fieldName))
        }
        uint8 c0 = uint8(s[0]);
        if (c0 < 0x61 || c0 > 0x7a) {
            return false;
        }
        for (uint256 i = 1; i < len; ++i) {
            uint8 c = uint8(s[i]);
            if ((c >= 0x61 && c <= 0x7a) || (c >= 0x41 && c <= 0x5a) || (c >= 0x30 && c <= 0x39)) {
                continue;
            }
            return false;
        }
        return true;
    }

    function __TagRegistry_getReflectVar(
        string calldata from,
        string calldata to,
        string calldata name,
        uint256[] calldata elemPath
    ) private view returns (ABI.ReflectVar memory) {
        __TagRegistry_Storage storage $ = __TagRegistry_getStorage();
        bytes memory abiType = $.types[from][name].abiType;
        ABI.ReflectVar memory rv = $.tags[from][to].get(name).bind(abiType);
        for (uint256 i = 0; i < elemPath.length; ++i) {
            rv = rv.at(elemPath[i]);
        }
        return rv;
    }

    function __TagRegistry_getStorage() private pure returns (__TagRegistry_Storage storage $) {
        assembly {
            $.slot := __TagRegistry_STORAGE
        }
    }
}
