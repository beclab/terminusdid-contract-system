// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface ITerminusDID {
    function getTagValue(uint256 tokenId, uint256 key) external view returns (bool exists, bytes memory value);
}

interface IRegistrar {
    function traceOwner(string calldata domain, address owner)
        external
        view
        returns (uint256 domainLevel, uint256 ownedLevel, string memory ownedDomain);

    function setTag(string calldata domain, uint256 key, bytes calldata value) external returns (bool addedOrRemoved);
}
