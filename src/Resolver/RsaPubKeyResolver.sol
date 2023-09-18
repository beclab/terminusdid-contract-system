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
*/
contract RsaPubKeyResolver {
    using Asn1Decode for bytes;

    function validate(bytes calldata pubKey) public pure returns (bool) {
        parse(pubKey);
        return true;
    }

    function parse(
        bytes calldata pubKey
    ) public pure returns (bytes memory modulus, uint256 publicExponent) {
        uint256 sequenceRange = pubKey.rootOfSequenceStringAt(0);
        bytes memory sequence = pubKey.bytesAt(sequenceRange);

        uint256 modulesRange = sequence.root();
        modulus = sequence.uintBytesAt(modulesRange);

        uint256 publicExponentRange = sequence.nextSiblingOf(modulesRange);
        publicExponent = sequence.uintAt(publicExponentRange);
    }
}
