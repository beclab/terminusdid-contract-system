// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {BytesUtils} from "ens-contracts/dnssec-oracle/BytesUtils.sol";
import {IResolver} from "./IResolver.sol";
import {ITerminusDID, IRegistrar} from "../utils/Interfaces.sol";
import {Asn1Decode} from "../utils/Asn1Decode.sol";
import {SignatureHelper} from "../utils/SignatureHelper.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";

contract RootResolver is IResolver, SignatureHelper, Context {
    using Asn1Decode for bytes;
    using BytesUtils for bytes;
    using DomainUtils for string;

    // http://oid-info.com/get/1.2.840.113549.1.1.1
    bytes private constant _OID_PKCS = hex"2a864886f70d010101";

    uint256 private constant _RSA_PUBKEY = 0x12;
    uint256 private constant _DNS_A_RECORD = 0x13;
    uint256 private constant _AUTH_ADDRESSES = 0x14;

    // signature is valid within 1 hour
    uint256 private constant VALID_SIG_INTERVAL = 60 * 60;

    address private _operator;
    IRegistrar private _registrar;
    ITerminusDID private _registry;

    error Unauthorized();
    error UnsupportedSigAlgorithm();
    error SignatureIsValidOnlyInOneHour(uint256 signAt, uint256 blockchainCurTimeStamp);
    error InvalidAddressSignature(address addr, bytes signature);
    error AddressNotFound(address addr);
    error AuthAddressNotExists();
    error AuthAddressAlreadyExists();
    error InvalidAction();

    struct AuthAddress {
        SigAlg algorithm;
        address addr;
    }

    modifier authorizationCheck(string calldata domain) {
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
        if (key == _RSA_PUBKEY) {
            return this.rsaPubKey.selector;
        } else if (key == _DNS_A_RECORD) {
            return this.dnsARecord.selector;
        } else if (key == _AUTH_ADDRESSES) {
            return this.authenticationAddress.selector;
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
    RSAPublicKey support RSA Pkcs8 ASN.1 format:
    EncryptedPrivateKeyInfo SEQUENE
        encryptionAlgorithm SEQUENCE
            algorithm OBJECT IDENTIFIER
            parameters
        encryptedData BIT STRING
            SEQUENCE
                INTEGER -- modulus
                INTEGER -- exponent
    */
    function setRsaPubKey(string calldata domain, bytes calldata pubKey) external authorizationCheck(domain) {
        if (pubKey.length == 0) {
            _registrar.setTag(domain, _RSA_PUBKEY, "");
        } else {
            uint256 encryptedPrivateKeyInfoRange = pubKey.rootOfSequenceStringAt(0);
            bytes memory encryptedPrivateKeyInfo = pubKey.bytesAt(encryptedPrivateKeyInfoRange);

            uint256 encryptionAlgorithmRange = encryptedPrivateKeyInfo.rootOfSequenceStringAt(0);
            {
                bytes memory encryptionAlgorithm = encryptedPrivateKeyInfo.bytesAt(encryptionAlgorithmRange);

                uint256 algorithmRange = encryptionAlgorithm.rootOfObjectIdentifierAt(0);
                bytes memory algorithm = encryptionAlgorithm.bytesAt(algorithmRange);
                require(algorithm.equals(_OID_PKCS), "Rsa pub key parsing: not PKCS format");
            }

            {
                uint256 encryptedDataRange = encryptedPrivateKeyInfo.nextSiblingOf(encryptionAlgorithmRange);
                bytes memory encryptedData = encryptedPrivateKeyInfo.bitstringAt(encryptedDataRange);

                uint256 sequenceRange = encryptedData.rootOfSequenceStringAt(0);
                bytes memory sequence = encryptedData.bytesAt(sequenceRange);

                uint256 modulusRange = sequence.root();
                sequence.uintBytesAt(modulusRange);

                uint256 publicExponentRange = sequence.nextSiblingOf(modulusRange);
                sequence.uintAt(publicExponentRange);
            }

            _registrar.setTag(domain, _RSA_PUBKEY, pubKey);
        }
    }

    function rsaPubKey(uint256 tokenId) external view returns (bytes memory pubKey) {
        (, pubKey) = _registry.getTagValue(tokenId, _RSA_PUBKEY);
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function setDnsARecord(string calldata domain, bytes4 ipv4) external authorizationCheck(domain) {
        if (ipv4 == bytes4(0)) {
            _registrar.setTag(domain, _DNS_A_RECORD, "");
        } else {
            _registrar.setTag(domain, _DNS_A_RECORD, bytes.concat(ipv4));
        }
    }

    function dnsARecord(uint256 tokenId) external view returns (bytes4 ipv4) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _DNS_A_RECORD);
        if (exists) {
            ipv4 = bytes4(value);
        }
    }

    /*
    Authentication addresses are addresses that the domain owner owns its private key
    */
    function addAuthenticationAddress(
        AuthAddressReq calldata authAddressReq,
        bytes calldata sigFromAddressPrivKey,
        bytes calldata sigFromDomainOwnerPrivKey
    ) external {
        // only support ethereum signature algorithm ECDSA so far
        if (authAddressReq.algorithm != SigAlg.ECDSA) {
            revert UnsupportedSigAlgorithm();
        }

        // should be add action
        if (authAddressReq.action != Action.Add) {
            revert InvalidAction();
        }

        // signature expired
        if (
            !(block.timestamp >= authAddressReq.signAt && block.timestamp <= authAddressReq.signAt + VALID_SIG_INTERVAL)
        ) {
            revert SignatureIsValidOnlyInOneHour(authAddressReq.signAt, block.timestamp);
        }

        // signature check for domain owner
        address domainOwner = recoverSigner(authAddressReq, sigFromDomainOwnerPrivKey);
        if (domainOwner != _registry.ownerOf(authAddressReq.domain.tokenId())) {
            revert Unauthorized();
        }

        // signature check for auth address
        if (authAddressReq.addr != recoverSigner(authAddressReq, sigFromAddressPrivKey)) {
            revert InvalidAddressSignature(authAddressReq.addr, sigFromAddressPrivKey);
        }

        // new add auth address
        AuthAddress memory newAddAuthAddr = AuthAddress(authAddressReq.algorithm, authAddressReq.addr);

        // auth addresses data structure: AuthAddress[]
        // if not exists, set to registry, otherwise append to.
        (bool exists, bytes memory value) = _registry.getTagValue(authAddressReq.domain.tokenId(), _AUTH_ADDRESSES);
        if (!exists) {
            AuthAddress[] memory addrs = new AuthAddress[](1);
            addrs[0] = newAddAuthAddr;
            _registrar.setTag(authAddressReq.domain, _AUTH_ADDRESSES, abi.encode(addrs));
        } else {
            AuthAddress[] memory curAddrs = abi.decode(value, (AuthAddress[]));
            AuthAddress[] memory newAddrs = new AuthAddress[](curAddrs.length + 1);
            for (uint256 i = 0; i < curAddrs.length; i++) {
                if (curAddrs[i].algorithm == authAddressReq.algorithm && curAddrs[i].addr == authAddressReq.addr) {
                    revert AuthAddressAlreadyExists();
                }
                newAddrs[i] = curAddrs[i];
            }
            newAddrs[curAddrs.length] = newAddAuthAddr;
            _registrar.setTag(authAddressReq.domain, _AUTH_ADDRESSES, abi.encode(newAddrs));
        }
    }

    function removeAuthenticationAddress(
        AuthAddressReq calldata authAddressReq,
        bytes calldata sigFromDomainOwnerPrivKey
    ) external {
        // only support ethereum signature algorithm ECDSA so far
        if (authAddressReq.algorithm != SigAlg.ECDSA) {
            revert UnsupportedSigAlgorithm();
        }

        // should be remove action
        if (authAddressReq.action != Action.Remove) {
            revert InvalidAction();
        }

        // signature expired
        if (
            !(block.timestamp >= authAddressReq.signAt && block.timestamp <= authAddressReq.signAt + VALID_SIG_INTERVAL)
        ) {
            revert SignatureIsValidOnlyInOneHour(authAddressReq.signAt, block.timestamp);
        }
        // signature check for domain owner
        address domainOwner = recoverSigner(authAddressReq, sigFromDomainOwnerPrivKey);
        if (domainOwner != _registry.ownerOf(authAddressReq.domain.tokenId())) {
            revert Unauthorized();
        }

        (bool exists, bytes memory value) = _registry.getTagValue(authAddressReq.domain.tokenId(), _AUTH_ADDRESSES);
        // no tag value at all
        if (!exists) {
            revert AuthAddressNotExists();
        }
        AuthAddress[] memory curAddrs = abi.decode(value, (AuthAddress[]));
        bool found;
        uint256 toDeleteIndex;
        for (uint256 i = 0; i < curAddrs.length; i++) {
            if (curAddrs[i].algorithm == authAddressReq.algorithm && curAddrs[i].addr == authAddressReq.addr) {
                found = true;
                toDeleteIndex = i;
                break;
            }
        }
        // no found address to be deleted
        if (!found) {
            revert AddressNotFound(authAddressReq.addr);
        }
        // found and tag value will be empty after delete the address, delete tag
        if (found && curAddrs.length == 1) {
            _registrar.setTag(authAddressReq.domain, _AUTH_ADDRESSES, "");
            return;
        }
        // remove found address
        AuthAddress[] memory newAddrs = new AuthAddress[](curAddrs.length - 1);
        for (uint256 i = 0; i < toDeleteIndex; i++) {
            newAddrs[i] = curAddrs[i];
        }
        for (uint256 i = toDeleteIndex + 1; i < curAddrs.length; i++) {
            newAddrs[i - 1] = curAddrs[i];
        }
        _registrar.setTag(authAddressReq.domain, _AUTH_ADDRESSES, abi.encode(newAddrs));
    }

    function authenticationAddress(uint256 tokenId) external view returns (AuthAddress[] memory addrs) {
        (bool exists, bytes memory value) = _registry.getTagValue(tokenId, _AUTH_ADDRESSES);
        if (exists) {
            addrs = abi.decode(value, (AuthAddress[]));
        }
    }
}
