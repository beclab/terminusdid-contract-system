// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "../Oracle.sol";
import "../OracleType.sol";

contract MetaResolver {
    event SetMeta(bytes32 indexed node, string did, address owner, OracleType.InfoType InfoType);

    Oracle public oracle;

    constructor(address _oracle) {
        oracle = Oracle(_oracle);
    }

    function setMeta(bytes32 node, string calldata did, address owner, OracleType.InfoType infoType) external {
        oracle.setMetadata(node, OracleType.Metadata({did: did, owner: owner, infoType: infoType}));
        emit SetMeta(node, did, owner, infoType);
    }

    function getMeta(bytes32 node) external view returns (string memory, address, OracleType.InfoType) {
        OracleType.Metadata memory meta = oracle.getMetadata(node);
        return (meta.did, meta.owner, meta.infoType);
    }
}
