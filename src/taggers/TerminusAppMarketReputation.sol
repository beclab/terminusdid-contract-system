// SPDX-License-Identifier: Apache-2.0
pragma solidity ^0.8.21;

import {IERC5267} from "@openzeppelin/contracts/interfaces/IERC5267.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {Multicall} from "@openzeppelin/contracts/utils/Multicall.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

import {TerminusDID} from "../core/TerminusDID.sol";

contract TerminusAppMarketReputation is IERC5267, Nonces, Multicall, IERC721Errors {
    enum CommentReactionType {
        Cancel,
        Like,
        Dislike
    }

    struct Rating {
        string reviewer;
        uint8 score;
    }

    string private constant NAME = "Terminus App Market Reputation";
    string private constant VERSION = "1";

    bytes32 private constant RATING_TYPEHASH =
        keccak256("Rating(string appId,string appVersion,string reviewer,uint8 score,uint256 nonce)");
    bytes32 private constant ADD_COMMENT_TYPEHASH =
        keccak256("AddComment(string appId,string appVersion,string reviewer,string content,uint256 nonce)");
    bytes32 private constant UPDATE_COMMENT_TYPEHASH =
        keccak256("UpdateComment(bytes32 commentId,string content,uint256 nonce)");
    bytes32 private constant DELETE_COMMENT_TYPEHASH = keccak256("DeleteComment(bytes32 commentId,uint256 nonce)");
    bytes32 private constant COMMENT_REACTION_TYPEHASH =
        keccak256("CommentReaction(string user,bytes32 commentId,uint8 reactionType,uint256 nonce)");
    bytes32 private constant COMMENT_ID_TYPEHASH =
        keccak256("CommentId(string appId,string appVersion,string reviewer,uint256 blockNumber)");

    string private constant TAGS_FROM = "app.myterminus.com";
    string private constant RATINGS_TAGNAME = "ratings";

    TerminusDID private immutable _didRegistry;

    uint256 private immutable _chainId;
    address private immutable _thisAddress;
    bytes32 private immutable _domainSeparator;

    mapping(bytes32 commentId => uint256 tokenId) private _commentTokenIds;

    mapping(string appTerminusName => mapping(string reviewer => uint256 index)) private _ratingIndex;

    event NewRating(string appId, string appVersion, string reviewer, uint8 score);

    event CommentAdded(string appId, string appVersion, string reviewer, bytes32 commentId, string content);

    event CommentUpdated(bytes32 commentId, string content);

    event CommentDeleted(bytes32 commentId);

    event NewCommentReaction(string user, bytes32 commentId, CommentReactionType reactionType);

    error ContextMismatch();

    error InvalidSigner(address signer, address owner);

    error NonexistentAppOrVersion(string appId, string version);

    error InvalidScore(uint8 score);

    error NonexistentComment(bytes32 commentId);

    error RejectedComment(bytes32 commentId);

    constructor(address didRegistry_) {
        _didRegistry = TerminusDID(didRegistry_);
        require(_didRegistry.isRegistered(TAGS_FROM), "TerminusAppMarketReputation: TAGS_FROM not registered yet");

        _chainId = block.chainid;
        _thisAddress = address(this);

        _domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                block.chainid,
                address(this)
            )
        );
    }

    function didRegistry() public view returns (address) {
        return address(_didRegistry);
    }

    function eip712Domain()
        public
        view
        returns (
            bytes1 fields,
            string memory name,
            string memory version,
            uint256 chainId,
            address verifyingContract,
            bytes32 salt,
            uint256[] memory extensions
        )
    {
        return (hex"0f", NAME, VERSION, _chainId, _thisAddress, bytes32(0), new uint256[](0));
    }

    function submitRating(
        string calldata appId,
        string calldata appVersion,
        string calldata reviewer,
        uint8 score,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        string memory appTerminusName = _appTerminusName(appId, appVersion);
        if (!_didRegistry.isRegistered(appTerminusName)) {
            revert NonexistentAppOrVersion(appId, appVersion);
        }

        address owner = _didRegistry.ownerOf(uint256(keccak256(bytes(reviewer))));
        bytes32 structHash = keccak256(
            abi.encode(
                RATING_TYPEHASH,
                keccak256(bytes(appId)),
                keccak256(bytes(appVersion)),
                keccak256(bytes(reviewer)),
                score,
                _useNonce(owner)
            )
        );

        address signer = ECDSA.recover(_eip712Digest(structHash), v, r, s);
        if (owner != signer) {
            revert InvalidSigner(signer, owner);
        }

        if (score < 1 || score > 5) {
            revert InvalidScore(score);
        }

        emit NewRating(appId, appVersion, reviewer, score);

        mapping(string => uint256) storage rIndex = _ratingIndex[appTerminusName];

        if (!_didRegistry.hasTag(TAGS_FROM, appTerminusName, RATINGS_TAGNAME)) {
            _didRegistry.addTag(TAGS_FROM, appTerminusName, RATINGS_TAGNAME, abi.encode(new Rating[](1)));
            rIndex[""] = 1;
        }

        uint256 index = rIndex[reviewer];
        if (index > 0) {
            uint256[] memory path = new uint256[](2);
            path[0] = index;
            path[1] = 1;
            _didRegistry.updateTagElem(TAGS_FROM, appTerminusName, RATINGS_TAGNAME, path, abi.encode(score));
        } else {
            index = rIndex[""];
            ++rIndex[""];
            rIndex[reviewer] = index;
            _didRegistry.pushTagElem(
                TAGS_FROM, appTerminusName, RATINGS_TAGNAME, new uint256[](0), abi.encode(Rating(reviewer, score))
            );
        }
    }

    function getCommentId(
        string calldata appId,
        string calldata appVersion,
        string calldata reviewer,
        uint256 blockNumber
    ) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                COMMENT_ID_TYPEHASH,
                keccak256(bytes(appId)),
                keccak256(bytes(appVersion)),
                keccak256(bytes(reviewer)),
                blockNumber
            )
        );
    }

    function existsCommentId(bytes32 commentId) public view returns (bool) {
        return _commentTokenIds[commentId] != 0;
    }

    function addComment(
        string calldata appId,
        string calldata appVersion,
        string calldata reviewer,
        string calldata content,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (!_didRegistry.isRegistered(_appTerminusName(appId, appVersion))) {
            revert NonexistentAppOrVersion(appId, appVersion);
        }

        uint256 tokenId = uint256(keccak256(bytes(reviewer)));
        address owner = _didRegistry.ownerOf(tokenId);
        bytes32 structHash = keccak256(
            abi.encode(
                ADD_COMMENT_TYPEHASH,
                keccak256(bytes(appId)),
                keccak256(bytes(appVersion)),
                keccak256(bytes(reviewer)),
                keccak256(bytes(content)),
                _useNonce(owner)
            )
        );

        address signer = ECDSA.recover(_eip712Digest(structHash), v, r, s);
        if (owner != signer) {
            revert InvalidSigner(signer, owner);
        }

        bytes32 commentId = getCommentId(appId, appVersion, reviewer, block.number);
        if (_commentTokenIds[commentId] != 0) {
            revert RejectedComment(commentId);
        }
        _commentTokenIds[commentId] = tokenId;

        emit CommentAdded(appId, appVersion, reviewer, commentId, content);
    }

    function updateComment(bytes32 commentId, string calldata content, uint8 v, bytes32 r, bytes32 s) public {
        uint256 tokenId = _commentTokenIds[commentId];
        if (tokenId == 0) {
            revert NonexistentComment(commentId);
        }

        address owner = _didRegistry.ownerOf(tokenId);
        bytes32 structHash =
            keccak256(abi.encode(UPDATE_COMMENT_TYPEHASH, commentId, keccak256(bytes(content)), _useNonce(owner)));

        address signer = ECDSA.recover(_eip712Digest(structHash), v, r, s);
        if (owner != signer) {
            revert InvalidSigner(signer, owner);
        }

        emit CommentUpdated(commentId, content);
    }

    function deleteComment(bytes32 commentId, uint8 v, bytes32 r, bytes32 s) public {
        uint256 tokenId = _commentTokenIds[commentId];
        if (tokenId == 0) {
            revert NonexistentComment(commentId);
        }

        address owner = _didRegistry.ownerOf(tokenId);
        bytes32 structHash = keccak256(abi.encode(DELETE_COMMENT_TYPEHASH, commentId, _useNonce(owner)));

        address signer = ECDSA.recover(_eip712Digest(structHash), v, r, s);
        if (owner != signer) {
            revert InvalidSigner(signer, owner);
        }

        delete _commentTokenIds[commentId];

        emit CommentDeleted(commentId);
    }

    function submitCommentReaction(
        string calldata user,
        bytes32 commentId,
        CommentReactionType reactionType,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) public {
        if (_commentTokenIds[commentId] == 0) {
            revert NonexistentComment(commentId);
        }

        address owner = _didRegistry.ownerOf(uint256(keccak256(bytes(user))));
        bytes32 structHash = keccak256(
            abi.encode(COMMENT_REACTION_TYPEHASH, keccak256(bytes(user)), commentId, reactionType, _useNonce(owner))
        );

        address signer = ECDSA.recover(_eip712Digest(structHash), v, r, s);
        if (owner != signer) {
            revert InvalidSigner(signer, owner);
        }

        emit NewCommentReaction(user, commentId, reactionType);
    }

    function _eip712Digest(bytes32 structHash) internal view returns (bytes32) {
        if (block.chainid != _chainId || address(this) != _thisAddress) {
            revert ContextMismatch();
        }
        return MessageHashUtils.toTypedDataHash(_domainSeparator, structHash);
    }

    function _appTerminusName(string calldata appId, string calldata appVersion)
        internal
        pure
        returns (string memory)
    {
        return string.concat(appVersion, ".", appId, ".", TAGS_FROM);
    }
}
