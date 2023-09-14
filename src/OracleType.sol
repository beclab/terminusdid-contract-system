// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

contract OracleType {
    enum InfoType {
        Person,
        Organization,
        Reality
    }

    struct Metadata {
        string domain;
        string did;
        address owner;
        InfoType infoType;
    }

    struct DomainInfo {
        Metadata metadata;
        mapping(string => bytes) extentedAttr;
    }
}
