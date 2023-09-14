// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "openzeppelin/access/Ownable.sol";

contract Oracle is Ownable {
    struct Metadata {
        string did;
        address owner;
        uint8 infoType;
    }

    struct DomainInfo {
        Metadata metadata;
        mapping(bytes32 => bytes) extentedAttr;
    }

    mapping(bytes32 => DomainInfo) public data;
    mapping(address => bool) public resolvers;

    modifier onlyResolver() {
        require(resolvers[msg.sender], "not valid resolver");
        _;
    }

    function getMetadata(bytes32 domainHash) public view returns (Metadata memory) {
        return data[domainHash].metadata;
    }

    function setMetadata(bytes32 domainHash, Metadata calldata metadata) public onlyResolver {
        data[domainHash].metadata = metadata;
    }

    function getExtentedAttr(bytes32 domainHash, bytes32 attrHash) public view returns (bytes memory) {
        return data[domainHash].extentedAttr[attrHash];
    }

    function setExtentedAttr(bytes32 domainHash, bytes32 attrHash, bytes calldata attrData) public onlyResolver {
        DomainInfo storage domainInfo = data[domainHash];
        domainInfo.extentedAttr[attrHash] = attrData;
    }

    function setResolver(address resolver) public onlyOwner {
        resolvers[resolver] = true;
    }
}
