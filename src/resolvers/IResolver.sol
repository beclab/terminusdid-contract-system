// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

interface IResolver {
    /**
     * @notice Checks whether the tag key is supported and validates the value.
     *
     * @dev MUST NOT revert inside function body.
     *
     * @param key   Tag key for checking compatibility and identifying value type.
     * @param value Tag value to validate.
     *
     * @return status Validation result code:
     *                - Passed(0),
     *                - KeyRejected(1),
     *                - KeyReservedButUnimplemented(2),
     *                - ValueInvalid(otherwise).
     */
    function validate(bytes8 key, bytes calldata value) external view returns (uint256 status);
}

// OPTIONAL: custom resolvers may freely choose whether or not to implement this extension.
interface IResolverWithParse is IResolver {
    /**
     * @notice Checks whether the tag key is supported and parses the value for easier use by other contracts.
     *
     * @dev MUST NOT revert inside function body.
     *
     * @param key   Tag key for checking compatibility and identifying value type.
     * @param value Tag value to parse.
     *
     * @return status MUST be the same as returned by `validate(key, value)`.
     * @return parsed Parsed ABI-encoded value in bytes. Typical use: `abi.decode(parsed, (...))`.
     *                SHOULD be empty if `status` is nonzero.
     */
    function parse(bytes8 key, bytes calldata value) external view returns (uint256 status, bytes memory parsed);
}
