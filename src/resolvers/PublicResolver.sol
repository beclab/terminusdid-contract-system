// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolverWithParse} from "./IResolver.sol";
import {RsaPubKeyResolver} from "./RsaPubKeyResolver.sol";
import {DnsARecordResolver} from "./DnsARecordResolver.sol";
import {CustomResolverAddressResolver} from "./CustomResolverAddressResolver.sol";

contract PublicResolver is IResolverWithParse, RsaPubKeyResolver, DnsARecordResolver, CustomResolverAddressResolver {
    uint32 private constant _PUBLIC_KEY_LIMIT = 0xffff;
    uint32 private constant _RSA_PUBKEY_RESOLVER = 0x12;
    uint32 private constant _DNS_A_RECORD_RESOLVER = 0x13;
    uint32 private constant _CUSTOM_RESOLVER = 0x97;

    /**
     * @return status
     *     0: passed
     *     1: not supported
     *     2: support but not defined
     *     4: DnsARecordResolver: value length should be 4
     *     5: RsaPubKeyResolver: value does not meet RSA Pkcs1 ASN.1 format
     *     6: CustomResolverAddressResolver: value length should be 20
     *     7: CustomResolverAddressResolver: customResolver has no validate method
     *     8: CustomResolverAddressResolver: customResolver is not allow to implement key within 0xffff
     */
    function validate(uint32 key, bytes calldata value) external view returns (uint256 status) {
        if (key > _PUBLIC_KEY_LIMIT) {
            return 1;
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            return rsaPubKeyResolverValidate(value);
        }

        if (key == _DNS_A_RECORD_RESOLVER) {
            return dnsARecordResolverValidate(value);
        }

        if (key == _CUSTOM_RESOLVER) {
            return customResolverAddressResolverValidate(value);
        }

        return 2;
    }

    function parse(uint32 key, bytes calldata value) external view returns (uint256 status, bytes memory parsed) {
        if (key > _PUBLIC_KEY_LIMIT) {
            return (1, "");
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            return rsaPubKeyResolverParse(value);
        }

        if (key == _DNS_A_RECORD_RESOLVER) {
            return dnsARecordResolverParse(value);
        }

        if (key == _CUSTOM_RESOLVER) {
            return customResolverAddressResolverParse(value);
        }

        return (2, "");
    }
}
