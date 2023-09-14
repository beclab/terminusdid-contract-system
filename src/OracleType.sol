// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract OracleType {
    enum InfoType {
        Person,
        Organization,
        Reality
    }

    struct Metadata {
        string did;
        address owner;
        InfoType infoType;
    }

    struct DomainInfo {
        Metadata metadata;
        mapping(bytes32 => bytes) extentedAttr;
    }
}
