// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.21;

import {Context} from "@openzeppelin/contracts/utils/Context.sol";
import {BytesUtils} from "ens-contracts/dnssec-oracle/BytesUtils.sol";
import {Asn1Decode} from "../utils/Asn1Decode.sol";
import {SignatureHelper} from "../utils/SignatureHelper.sol";
import {DomainUtils} from "../utils/DomainUtils.sol";
import {TerminusDID} from "../core/TerminusDID.sol";

contract RootTagger is SignatureHelper, Context {
    using Asn1Decode for bytes;
    using BytesUtils for bytes;
    using DomainUtils for string;

    // http://oid-info.com/get/1.2.840.113549.1.1.1
    bytes private constant _OID_PKCS = hex"2a864886f70d010101";

    // signature is valid within 1 hour
    uint256 private constant VALID_SIG_INTERVAL = 60 * 60;

    TerminusDID private _terminusDID;
    address private _operator;

    string private _rootDomain = "";
    string private _rsaPubKeyTagName = "rsaPubKey";
    string private _dnsARecordTagName = "dnsARecord";
    string private _authAddressesTagName = "authAddresses";
    string private _latestDIDTagName = "latestDID";

    error Unauthorized();
    error RootTagNoExists(string domain, string tagName);
    error UnsupportedSigAlgorithm();
    error InvalidAction();
    error SignatureIsValidOnlyInOneHour(uint256 signAt, uint256 blockchainCurTimeStamp);
    error InvalidAddressSignature(address addr, bytes signature);
    error InvalidIndex();

    struct AuthAddress {
        SigAlg algorithm;
        address addr;
    }

    modifier authorizationCheck(string calldata domain) {
        address caller = _msgSender();
        if (caller != _operator) {
            (, uint256 ownedLevel,) = _terminusDID.traceOwner(domain, caller);
            if (ownedLevel == 0) {
                revert Unauthorized();
            }
        }
        _;
    }

    constructor(address terminusDID_, address operator_) {
        _terminusDID = TerminusDID(terminusDID_);
        _operator = operator_;
    }

    function terminusDID() external view returns (address) {
        return address(_terminusDID);
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
        bool hasTag = _terminusDID.hasTag(_rootDomain, domain, _rsaPubKeyTagName);

        // remove rsaPubKey
        if (pubKey.length == 0) {
            if (!hasTag) {
                revert RootTagNoExists(domain, _rsaPubKeyTagName);
            }
            return _terminusDID.removeTag(_rootDomain, domain, _rsaPubKeyTagName);
        }

        _rsaPubKeyCheck(pubKey);

        // update rsaPubKey
        if (hasTag) {
            uint256[] memory elemPath;
            _terminusDID.updateTagElem(_rootDomain, domain, _rsaPubKeyTagName, elemPath, abi.encode(pubKey));
        } else {
            // add rsaPubKey
            _terminusDID.addTag(_rootDomain, domain, _rsaPubKeyTagName, abi.encode(pubKey));
        }
    }

    function getRsaPubKey(string calldata domain) external view returns (bytes memory) {
        if (!_terminusDID.hasTag(_rootDomain, domain, _rsaPubKeyTagName)) {
            revert RootTagNoExists(domain, _rsaPubKeyTagName);
        }
        uint256[] memory elemPath;
        bytes memory gotData = _terminusDID.getTagElem(_rootDomain, domain, _rsaPubKeyTagName, elemPath);
        return abi.decode(gotData, (bytes));
    }

    function _rsaPubKeyCheck(bytes calldata pubKey) internal pure {
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
    }

    /*
    DNS A record can be represent by 4 bytes, in which each byte represents a number range from 0 to 255.
    The raw bytes data length must be 4.
    */
    function setDnsARecord(string calldata domain, bytes4 ipv4) external authorizationCheck(domain) {
        bool hasTag = _terminusDID.hasTag(_rootDomain, domain, _dnsARecordTagName);
        // remove dnsARecord
        if (ipv4 == bytes4(0)) {
            if (!hasTag) {
                revert RootTagNoExists(domain, _dnsARecordTagName);
            }
            return _terminusDID.removeTag(_rootDomain, domain, _dnsARecordTagName);
        }

        // update dnsARecord
        if (hasTag) {
            uint256[] memory elemPath;
            _terminusDID.updateTagElem(_rootDomain, domain, _dnsARecordTagName, elemPath, abi.encode(ipv4));
        } else {
            // add dnsARecord
            _terminusDID.addTag(_rootDomain, domain, _dnsARecordTagName, abi.encode(ipv4));
        }
    }

    function getDnsARecord(string calldata domain) external view returns (bytes4) {
        if (!_terminusDID.hasTag(_rootDomain, domain, _dnsARecordTagName)) {
            revert RootTagNoExists(domain, _dnsARecordTagName);
        }
        uint256[] memory elemPath;
        bytes memory gotData = _terminusDID.getTagElem(_rootDomain, domain, _dnsARecordTagName, elemPath);
        return abi.decode(gotData, (bytes4));
    }

    /*
    Authentication addresses are addresses that the domain owner owns its private key
    */
    function addAuthenticationAddress(
        AuthAddressReq calldata authAddressReq,
        bytes calldata sigFromAddressPrivKey,
        bytes calldata sigFromDomainOwnerPrivKey
    ) external {
        // check
        _authAddressCommonCheck(authAddressReq, sigFromDomainOwnerPrivKey, Action.Add);

        // signature check for auth address
        if (authAddressReq.addr != recoverSigner(authAddressReq, sigFromAddressPrivKey)) {
            revert InvalidAddressSignature(authAddressReq.addr, sigFromAddressPrivKey);
        }

        // new add auth address
        AuthAddress memory newAddAuthAddr = AuthAddress(authAddressReq.algorithm, authAddressReq.addr);

        // auth addresses data structure: AuthAddress[]
        // if no exists, addTag, otherwise append to.
        bool hasTag = _terminusDID.hasTag(_rootDomain, authAddressReq.domain, _authAddressesTagName);
        // append
        if (hasTag) {
            uint256[] memory elemPath;
            _terminusDID.pushTagElem(
                _rootDomain, authAddressReq.domain, _authAddressesTagName, elemPath, abi.encode(newAddAuthAddr)
            );
        } else {
            // addTag
            AuthAddress[] memory addrs = new AuthAddress[](1);
            addrs[0] = newAddAuthAddr;
            _terminusDID.addTag(_rootDomain, authAddressReq.domain, _authAddressesTagName, abi.encode(addrs));
        }
    }

    function removeAuthenticationAddress(
        AuthAddressReq calldata authAddressReq,
        bytes calldata sigFromDomainOwnerPrivKey,
        uint256 index
    ) external {
        // check
        _authAddressCommonCheck(authAddressReq, sigFromDomainOwnerPrivKey, Action.Remove);

        bool hasTag = _terminusDID.hasTag(_rootDomain, authAddressReq.domain, _authAddressesTagName);
        // no tag value at all
        if (!hasTag) {
            revert RootTagNoExists(authAddressReq.domain, _authAddressesTagName);
        }

        uint256[] memory elemPath;
        uint256 len = _terminusDID.getTagElemLength(_rootDomain, authAddressReq.domain, _authAddressesTagName, elemPath);
        if (index >= len) {
            revert InvalidIndex();
        }

        // get the toDelete address, check whether it is the same with request address
        uint256[] memory addressPath = new uint256[](1);
        addressPath[0] = index;
        bytes memory toDeleteAddressData =
            _terminusDID.getTagElem(_rootDomain, authAddressReq.domain, _authAddressesTagName, addressPath);
        AuthAddress memory toDeleteAddress = abi.decode(toDeleteAddressData, (AuthAddress));
        if (!(toDeleteAddress.algorithm == authAddressReq.algorithm && toDeleteAddress.addr == authAddressReq.addr)) {
            revert InvalidIndex();
        }

        // if the toDelete address is the only address then remove tag
        if (len == 1) {
            return _terminusDID.removeTag(_rootDomain, authAddressReq.domain, _authAddressesTagName);
        }

        // swap the last address with toDelete address and pop the authAddresses array
        if (index == len - 1) {
            _terminusDID.popTagElem(_rootDomain, authAddressReq.domain, _authAddressesTagName, elemPath);
        } else {
            addressPath[0] = len - 1;
            bytes memory lastAuthAddressData =
                _terminusDID.getTagElem(_rootDomain, authAddressReq.domain, _authAddressesTagName, addressPath);
            addressPath[0] = index;
            _terminusDID.updateTagElem(
                _rootDomain, authAddressReq.domain, _authAddressesTagName, addressPath, lastAuthAddressData
            );
            _terminusDID.popTagElem(_rootDomain, authAddressReq.domain, _authAddressesTagName, elemPath);
        }
    }

    function getAuthenticationAddresses(string calldata domain) external view returns (AuthAddress[] memory) {
        bool hasTag = _terminusDID.hasTag(_rootDomain, domain, _authAddressesTagName);
        if (!hasTag) {
            revert RootTagNoExists(domain, _authAddressesTagName);
        }

        uint256[] memory elemPath;
        bytes memory gotData = _terminusDID.getTagElem(_rootDomain, domain, _authAddressesTagName, elemPath);
        return abi.decode(gotData, (AuthAddress[]));
    }

    function _authAddressCommonCheck(
        AuthAddressReq calldata authAddressReq,
        bytes calldata sigFromDomainOwnerPrivKey,
        Action action
    ) internal view {
        // only support ethereum signature algorithm ECDSA so far
        if (authAddressReq.algorithm != SigAlg.ECDSA) {
            revert UnsupportedSigAlgorithm();
        }

        // should be correct action (Add, Remove, Modify)
        if (authAddressReq.action != action) {
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
        if (domainOwner != _terminusDID.ownerOf(authAddressReq.domain.tokenId())) {
            revert Unauthorized();
        }
    }

    // latestDID is a string type tag
    function setLatestDID(string calldata domain, string calldata latestDID) external authorizationCheck(domain) {
        bool hasTag = _terminusDID.hasTag(_rootDomain, domain, _latestDIDTagName);
        // remove latestDID
        if (bytes(latestDID).length == 0) {
            if (!hasTag) {
                revert RootTagNoExists(domain, _latestDIDTagName);
            }
            return _terminusDID.removeTag(_rootDomain, domain, _latestDIDTagName);
        }

        // update latestDID
        if (hasTag) {
            uint256[] memory elemPath;
            _terminusDID.updateTagElem(_rootDomain, domain, _latestDIDTagName, elemPath, abi.encode(latestDID));
        } else {
            // add dnsARecord
            _terminusDID.addTag(_rootDomain, domain, _latestDIDTagName, abi.encode(latestDID));
        }
    }

    function getLatestDID(string calldata domain) external view returns (string memory) {
        if (!_terminusDID.hasTag(_rootDomain, domain, _latestDIDTagName)) {
            revert RootTagNoExists(domain, _latestDIDTagName);
        }
        uint256[] memory elemPath;
        bytes memory gotData = _terminusDID.getTagElem(_rootDomain, domain, _latestDIDTagName, elemPath);
        return abi.decode(gotData, (string));
    }
}
