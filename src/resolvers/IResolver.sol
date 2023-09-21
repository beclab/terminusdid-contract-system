// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IResolver {
    /**
     * @notice Checks whether the tag key is supported and validates the value.
     *
     * @param key   Tag key for checking compatibility and identifying value type.
     * @param value Tag value to validate.
     *
     * @return status Validation result code:
     *                        0 - Passed
     *                        1 - KeyRejected
     *                        2 - KeyReservedButNotImplemented
     *                otherwise - ValueInvalid.
     */
    function validate(bytes8 key, bytes calldata value) external view returns (uint256 status);
}

// OPTIONAL: custom resolvers may freely choose whether or not to implement this extension.
interface IResolverWithParse is IResolver {
    /**
     * @notice Checks whether the tag key is supported and parses the value for easier use by other contracts.
     *
     * @param key   Tag key for checking compatibility and identifying value type.
     * @param value Tag value to parse.
     *
     * @return status MUST be the same as returned by `validate(key, value)`.
     * @return parsed Parsed ABI-encoded value in bytes. Typical use: `abi.decode(parsed, (...))`.
     */
    function parse(bytes8 key, bytes calldata value) external view returns (uint256 status, bytes memory parsed);
}
