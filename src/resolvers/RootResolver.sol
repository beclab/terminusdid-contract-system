// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {IResolver} from "./IResolver.sol";
import {ITerminusDID, IRegistrar} from "../utils/Interfaces.sol";
import {Asn1Decode} from "../utils/Asn1Decode.sol";

contract RootResolver is IResolver, Context {
    using Asn1Decode for bytes;

    uint256 private constant _RSA_PUBKEY_RESOLVER = 0x12;
    uint256 private constant _DNS_A_RECORD_RESOLVER = 0x13;

    address private _operator;
    IRegistrar private _registrar;
    ITerminusDID private _registry;

    error Unauthorized();

    error Asn1DecodeError(Asn1Decode.ErrorCode errorCode);

    modifier authorizationCheck(string memory domain) {
        address caller = _msgSender();
        if (caller != _operator) {
            (, uint256 ownedLevel,) = _registrar.traceOwner(domain, caller);
            if (ownedLevel == 0) {
                revert Unauthorized();
            }
        }
        _;
    }

    constructor(address registrar_, address registry_, address operator_) {
        _registrar = IRegistrar(registrar_);
        _registry = ITerminusDID(registry_);
        _operator = operator_;
    }

    function tagGetter(uint256 key) external pure returns (bytes4) {
        if (key == _RSA_PUBKEY_RESOLVER) {
            return this.rsaPubKey.selector;
        } else if (key == _DNS_A_RECORD_RESOLVER) {
            return this.dnsARecord.selector;
        } else if (key <= 0xffff) {
            return bytes4(0xffffffff);
        } else {
            return 0;
        }
    }

    function registrar() external view returns (address) {
        return address(_registrar);
    }

    function registry() external view returns (address) {
        return address(_registry);
    }

    function operator() external view returns (address) {
        return _operator;
    }

    /*
    support RSA Pkcs1 ASN.1 format.
    RSAPublicKey ::= SEQUENCE {
        modulus           INTEGER,  -- n
        publicExponent    INTEGER   -- e
    }
    refs to: https://www.rfc-editor.org/rfc/rfc3447#appendix-A.1
            http://luca.ntop.org/Teaching/Appunti/asn1.html
    */
    function setRsaPubKey(string calldata domain, bytes calldata pubKey) external authorizationCheck(domain) {
        if (pubKey.length == 0) {
            _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, "");
        } else {
            Asn1Decode.ErrorCode errorCode;
            uint256 sequenceRange;
            (errorCode, sequenceRange) = pubKey.rootOfSequenceStringAt(0);
            if (errorCode != Asn1Decode.ErrorCode.NoError) {
                revert Asn1DecodeError(errorCode);
            }
            bytes memory sequence = pubKey.bytesAt(sequenceRange);

            uint256 modulusRange;
            (errorCode, modulusRange) = sequence.root();
            if (errorCode != Asn1Decode.ErrorCode.NoError) {
                revert Asn1DecodeError(errorCode);
            }

            (errorCode,) = sequence.uintBytesAt(modulusRange);
            if (errorCode != Asn1Decode.ErrorCode.NoError) {
                revert Asn1DecodeError(errorCode);
            }

            uint256 publicExponentRange;
            (errorCode, publicExponentRange) = sequence.nextSiblingOf(modulusRange);
            if (errorCode != Asn1Decode.ErrorCode.NoError) {
                revert Asn1DecodeError(errorCode);
            }

            (errorCode,) = sequence.uintAt(publicExponentRange);
            if (errorCode != Asn1Decode.ErrorCode.NoError) {
                revert Asn1DecodeError(errorCode);
            }

            _registrar.setTag(domain, _RSA_PUBKEY_RESOLVER, pubKey);
        }
    }

    function rsaPubKey(uint256 tokenId) external view returns (bytes memory pubKey) {
        (, pubKey) = _registry.getTagValue(tokenId, _RSA_PUBKEY_RESOLVER);
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function setDnsARecord(string memory domain, bytes4 ipv4) external authorizationCheck(domain) {
        if (ipv4 == bytes4(0)) {
            _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, "");
        } else {
            _registrar.setTag(domain, _DNS_A_RECORD_RESOLVER, bytes.concat(ipv4));
        }
    }

    function dnsARecord(uint256 tokenId) external view returns (bytes4 ipv4) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _DNS_A_RECORD_RESOLVER);
        if (exists) {
            ipv4 = bytes4(value);
        }
    }
}
