// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {IResolverWithParse} from "./IResolver.sol";
import {RsaPubKeyResolver} from "./RsaPubKeyResolver.sol";
import {DnsARecordResolver} from "./DnsARecordResolver.sol";

contract PublicResolver is IResolverWithParse, RsaPubKeyResolver, DnsARecordResolver {
    uint64 private constant _PUBLIC_KEY_LIMIT = uint64(type(uint16).max);
    bytes8 private constant _RSA_PUBKEY_RESOLVER = bytes8(uint64(0x12));
    bytes8 private constant _DNS_A_RECORD_RESOLVER = bytes8(uint64(0x13));

    /**
     * @return status
     *     0: passed
     *     1: not supported
     *     2: support but not defined
     *     4: DnsARecordResolver: value length should be 4
     *     5: RsaPubKeyResolver: value does not meet RSA Pkcs1 ASN.1 format
     */
    function validate(bytes8 key, bytes calldata value) external pure returns (uint256 status) {
        if (uint64(key) > _PUBLIC_KEY_LIMIT) {
            return 1;
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            return rsaPubKeyResolverValidate(value);
        }

        if (key == _DNS_A_RECORD_RESOLVER) {
            return dnsARecordResolverValidate(value);
        }

        return 2;
    }

    function parse(bytes8 key, bytes calldata value) external pure returns (uint256 status, bytes memory parsed) {
        if (uint64(key) > _PUBLIC_KEY_LIMIT) {
            return (1, "");
        }

        if (key == _RSA_PUBKEY_RESOLVER) {
            return rsaPubKeyResolverParse(value);
        }

        if (key == _DNS_A_RECORD_RESOLVER) {
            return dnsARecordResolverParse(value);
        }

        return (2, "");
    }
}
