// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {OracleType} from "../OracleType.sol";
import {BaseResolver} from "./BaseResolver.sol";

abstract contract MetaResolver is BaseResolver {
    event SetMeta(string indexed domain, string indexed did, address indexed owner, OracleType.InfoType InfoType);

    function setMeta(
        bytes32 node,
        string calldata domain,
        string calldata did,
        address owner,
        OracleType.InfoType infoType
    ) external {
        require(keccak256(bytes(domain)) == node, "MetaResolver: domain name and hash mismatch");
        oracle.setMetadata(node, OracleType.Metadata({domain: domain, did: did, owner: owner, infoType: infoType}));
        emit SetMeta(domain, did, owner, infoType);
    }

    function getMeta(bytes32 node) external view returns (string memory, string memory, address, OracleType.InfoType) {
        OracleType.Metadata memory meta = oracle.getMetadata(node);
        return (meta.domain, meta.did, meta.owner, meta.infoType);
    }
}
