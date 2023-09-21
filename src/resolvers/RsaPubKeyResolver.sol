// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Asn1Decode} from "../utils/Asn1Decode.sol";

/*
support RSA Pkcs1 ASN.1 format
RSAPublicKey ::= SEQUENCE {
    modulus           INTEGER,  -- n
    publicExponent    INTEGER   -- e
}
refs to: https://www.rfc-editor.org/rfc/rfc3447#appendix-A.1
         http://luca.ntop.org/Teaching/Appunti/asn1.html
*/
contract RsaPubKeyResolver {
    using Asn1Decode for bytes;

    function rsaPubKeyResolverValidate(bytes calldata pubKey) public pure returns (uint256) {
        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return 5;
        }
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

        uint256 modulusRange;
        (errorCode, modulusRange) = sequence.root();
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return 5;
        }

        (errorCode,) = sequence.uintBytesAt(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return 5;
        }

        uint256 publicExponentRange;
        (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return 5;
        }

        (errorCode,) = sequence.uintAt(publicExponentRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return 5;
        }

        return 0;
    }

    function rsaPubKeyResolverParse(bytes calldata pubKey) public pure returns (uint256, bytes memory) {
        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return (5, "");
        }
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

        uint256 modulusRange;
        (errorCode, modulusRange) = sequence.root();
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return (5, "");
        }

        bytes memory modulus;
        (errorCode, modulus) = sequence.uintBytesAt(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return (5, "");
        }

        uint256 publicExponentRange;
        (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return (5, "");
        }

        uint256 publicExponent;
        (errorCode, publicExponent) = sequence.uintAt(publicExponentRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return (5, "");
        }

        return (0, abi.encode(modulus, publicExponent));
    }
}
