// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

/**
 * @title Custom resolver interface for Terminus DID tags.
 *
 * @dev Besides the required functions listed in this interface, a resolver
 *      MUST provide a external view getter function for every defined tag
 *      with name <tagName> and parameter list `(uint256 tokenId)`,
 *      where <tagName> is the tag name in `camelCase`,
 *      e.g. `cardNumber(uint256 tokenId)`.
 *
 *      For the purpose of this documentation, the required getter function
 *      mentioned above is called the *standard getter* of that tag.
 *
 *      Resolvers MAY also provide other getters for a single tag.
 *
 *      Public setters are OPTIONAL and can be defined as needed.
 */
interface IResolver {
    /**
     * @notice Querys the getter function of a tag.
     *
     * @dev MUST use at most 30,000 gas.
     *
     * @param key Tag key as used in registry contract.
     *
     * @return If the tag key is
     *         defined => returns function selector of the tag's *standard getter*;
     *         not defined but reserved for future use => returns 0xffffffff;
     *         neither defined nor reserved => returns 0x00000000.
     *
     * Note: resolvers of subdomains cannot control a tag defined or reserved by any parent.
     */
    function tagGetter(uint256 key) external view returns (bytes4);
}
