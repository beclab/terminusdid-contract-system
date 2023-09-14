// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {OracleType} from "./OracleType.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";

contract Oracle is Ownable, OracleType {
    event AddResolver(address indexed resolver);
    event RemoveResolver(address indexed resolver);

    mapping(bytes32 => DomainInfo) private _data;
    mapping(address => bool) private _resolvers;

    modifier onlyResolver() {
        require(_resolvers[msg.sender], "Oracle: not valid resolver");
        _;
    }

    function getMetadata(bytes32 domainHash) public view onlyResolver returns (Metadata memory) {
        return _data[domainHash].metadata;
    }

    function setMetadata(bytes32 domainHash, Metadata calldata metadata) public onlyResolver {
        _data[domainHash].metadata = metadata;
    }

    function getExtentedAttr(bytes32 domainHash, string calldata attrKey)
        public
        view
        onlyResolver
        returns (bytes memory)
    {
        return _data[domainHash].extentedAttr[attrKey];
    }

    function setExtentedAttr(bytes32 domainHash, string calldata attrKey, bytes calldata attrData)
        public
        onlyResolver
    {
        DomainInfo storage domainInfo = _data[domainHash];
        domainInfo.extentedAttr[attrKey] = attrData;
    }

    function addResolver(address resolver) public onlyOwner {
        _resolvers[resolver] = true;
        emit AddResolver(resolver);
    }

    function removeResolver(address resolver) public onlyOwner {
        _resolvers[resolver] = false;
        emit RemoveResolver(resolver);
    }
}
