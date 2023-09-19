// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import "forge-std/console.sol";
import "../utils/Asn1Decode.sol";

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

    mapping(Asn1Decode.ErrorCode => string) errorMap;

    constructor() {
        errorMap[Asn1Decode.ErrorCode.NotTypeSequenceString] = "NotTypeSequenceString";
        errorMap[Asn1Decode.ErrorCode.NotTypeInteger] = "NotTypeInteger";
        errorMap[Asn1Decode.ErrorCode.NotPositive] = "NotPositive";
        errorMap[Asn1Decode.ErrorCode.EncodingTooLong] = "EncodingTooLong";
        errorMap[Asn1Decode.ErrorCode.WrongLength] = "WrongLength";
    }

    function validate(bytes calldata pubKey) public pure returns (bool) {
        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return false;
        }
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

        uint256 modulusRange;
        (errorCode, modulusRange) = sequence.root();
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return false;
        }

        (errorCode,) = sequence.uintBytesAt(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return false;
        }

        uint256 publicExponentRange;
        (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return false;
        }

        (errorCode,) = sequence.uintAt(publicExponentRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            return false;
        }

        return true;
    }

    function parse(bytes calldata pubKey) public view returns (bytes memory modulus, uint256 publicExponent) {
        Asn1Decode.ErrorCode errorCode;
        uint256 sequenceRange;
        (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert(errorMap[errorCode]);
        }
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

        uint256 modulusRange;
        (errorCode, modulusRange) = sequence.root();
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert(errorMap[errorCode]);
        }

        (errorCode, modulus) = sequence.uintBytesAt(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert(errorMap[errorCode]);
        }

        uint256 publicExponentRange;
        (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert(errorMap[errorCode]);
        }

        (errorCode, publicExponent) = sequence.uintAt(publicExponentRange);
        if (errorCode != Asn1Decode.ErrorCode.NoError) {
            revert(errorMap[errorCode]);
        }
    }
}
