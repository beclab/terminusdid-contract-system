// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IResolver {
    /**
     * @notice Checks if a tag key is defined or reserved by this resolver.
     *
     * @dev MUST use at most 30,000 gas.
     *
     * @param key Tag key as used in registry contract.
     */
    function supportsTag(uint256 key) external view returns (bool);
}
