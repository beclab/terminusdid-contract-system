// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import {DomainUtils} from "../utils/DomainUtils.sol";

struct Metadata {
    string domain;
    string did;
    string notes;
    bool allowSubdomain;
}

abstract contract MetadataRegistryUpgradeable is Initializable {
    using DomainUtils for string;
    using DomainUtils for DomainUtils.Slice;

    /// @custom:storage-location erc7201:terminus.MetadataRegistry
    struct __MetadataRegistry_Storage {
        mapping(uint256 id => Metadata) _data;
    }

    // keccak256(abi.encode(uint256(keccak256("terminus.MetadataRegistry")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant __MetadataRegistry_STORAGE =
        0x466d3c870aab1258d49b7f18efe13ece7618ec3cea991de4bd387e5720c64500;

    error UnregisteredParentDomain();

    error DisallowedSubdomain();

    error InvalidDomainLabel();

    error ExistentDomain();

    function __MetadataRegistry_init() internal onlyInitializing {}

    function __MetadataRegistry_init_unchained() internal onlyInitializing {}

    function __MetadataRegistry_get(uint256 id) internal view returns (Metadata memory) {
        return __MetadataRegistry_getStorage()._data[id];
    }

    function __MetadataRegistry_registered(string memory domain) internal view returns (bool) {
        return !__MetadataRegistry_getStorage()._data[domain.tokenId()].domain.isEmpty();
    }

    function __MetadataRegistry_id(string memory domain) internal pure returns (uint256) {
        return domain.tokenId();
    }

    function __MetadataRegistry_register(Metadata memory metadata) internal returns (uint256 id) {
        (DomainUtils.Slice label, DomainUtils.Slice parent, bool hasParent) = metadata.domain.cut();

        if (hasParent) {
            Metadata memory parentData = __MetadataRegistry_get(parent.tokenId());
            if (parentData.domain.isEmpty()) {
                revert UnregisteredParentDomain();
            }
            if (!parentData.allowSubdomain) {
                revert DisallowedSubdomain();
            }
        }

        if (!label.isValidLabel()) {
            revert InvalidDomainLabel();
        }

        id = metadata.domain.tokenId();
        if (!__MetadataRegistry_get(id).domain.isEmpty()) {
            revert ExistentDomain();
        }
        __MetadataRegistry_getStorage()._data[id] = metadata;
    }

    function __MetadataRegistry_getStorage() private pure returns (__MetadataRegistry_Storage storage $) {
        assembly {
            $.slot := __MetadataRegistry_STORAGE
        }
    }
}
