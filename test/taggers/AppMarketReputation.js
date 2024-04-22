const { loadFixture, time } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { BigNumber, utils, constants, getContractFactory, getSigners } = ethers;
const { AddressZero } = constants;

const CommentReactionType = {
    Cancel: 0,
    Like: 1,
    Dislike: 2
};

describe('AppMarket Reputation Test', function () {
    async function deployTokenFixture() {
        const [deployer, ...signers] = await getSigners();
        const operator = deployer;

        let ABI = await getContractFactory('src/utils/external/ABI.sol:ABI');
        let abiLib = await ABI.deploy();

        let TerminusDID = await getContractFactory('TerminusDID', {
            libraries: {
                ABI: abiLib.address,
              },
        });

        const name = 'TerminusDID';
        const symbol = 'TDID';

        let terminusDIDProxy = await upgrades.deployProxy(TerminusDID, [name, symbol], { 
            initializer: 'initialize',
            kind: 'uups', 
            constructorArgs: [], 
            unsafeAllow: ['state-variable-immutable', 'external-library-linking'] 
        })
        await terminusDIDProxy.deployed();

        await terminusDIDProxy.setOperator(operator.address);

        const tagsFrom = 'app.myterminus.com';
        const tagName = 'ratings';

        const hasDomain = await terminusDIDProxy.isRegistered(tagsFrom);
        if (!hasDomain) {
            // register domain
            const domain1 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
                domain: 'com',
                did: 'did',
                notes: 'local test for AppStore Reputation contract',
                allowSubdomain: true
            }]);

            const domain2 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
                domain: 'myterminus.com',
                did: 'did',
                notes: 'local test for AppStore Reputation contract',
                allowSubdomain: true
            }]);

            const domain3 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
                domain: 'app.myterminus.com',
                did: 'did',
                notes: 'local test for AppStore Reputation contract',
                allowSubdomain: true
            }]);

            await terminusDIDProxy.connect(operator).multicall([domain1, domain2, domain3]);
            console.log(`${tagsFrom} has been registered!`);
        } else {
            console.log(`${tagsFrom} is already registered!`);
        }

        /*
            struct Rating {
                string reviewer;
                uint8 score;
            }
            Rating[] type bytes: 0x04060002030101
        */
        const ratingType = utils.arrayify('0x04060002030101');
        const fieldNames = new Array();
        fieldNames.push(['reviewer', 'score']);
        await terminusDIDProxy.connect(operator).defineTag(tagsFrom, tagName, ratingType, fieldNames);

        const TerminusAppMarketReputation = await getContractFactory('TerminusAppMarketReputation');
        const appMarketReputation = await TerminusAppMarketReputation.deploy(terminusDIDProxy.address);
        await appMarketReputation.deployed();
        
        await terminusDIDProxy.connect(operator).setTagger(tagsFrom, tagName, appMarketReputation.address);

        return { appMarketReputation, terminusDIDProxy, operator, signers };
    }


    it('submitRating test', async function () {
        const { appMarketReputation, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        expect(terminusDIDProxy.address).to.equal(await appMarketReputation.didRegistry());
        
        const domainOwner = signers[0];
        const reviewer = 'testUser.com';
        // to be a qualified address to submit rating, the address should own a domain
        await terminusDIDProxy.register(domainOwner.address, {
            domain: reviewer,
            did: 'did',
            notes: 'local test for AppStore Reputaion contract',
            allowSubdomain: true
        })

        const domain = await getDomain(domainOwner, appMarketReputation.address);

        const types = getRatingTypes();

        const appId = 'myApp';
        const appVersion = '1'
        let score = 3;

        // register 1.myApp.app.myterminus.com
        const domain1 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
            domain: 'myApp.app.myterminus.com',
            did: 'did',
            notes: 'local test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        const domain2 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
            domain: '1.myApp.app.myterminus.com',
            did: 'did',
            notes: 'local test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        await terminusDIDProxy.connect(operator).multicall([domain1, domain2]);

        // The data to sign
        let value = {
            appId,
            appVersion,
            reviewer,
            score,
            nonce: await appMarketReputation.nonces(domainOwner.address)
        };

        let sig = await domainOwner._signTypedData(domain, types, value);

        let {v, r, s} = getVRSfromSig(sig);
        await expect(appMarketReputation.connect(operator).submitRating(appId, appVersion, reviewer, score, v, r, s))
            .to.emit(appMarketReputation, 'NewRating')
            .withArgs(appId, appVersion, reviewer, score);

        // replay attrack
        await expect(appMarketReputation.connect(operator).submitRating(appId, appVersion, reviewer, score, v, r, s))
            .to.be.revertedWithCustomError(appMarketReputation, 'InvalidSigner');

        // update rating
        score = 5;
        value = {
            appId,
            appVersion,
            reviewer,
            score,
            nonce: await appMarketReputation.nonces(domainOwner.address)
        };

        sig = await domainOwner._signTypedData(domain, types, value);
        let ret = getVRSfromSig(sig);
        v = ret.v;
        r = ret.r;
        s = ret.s;

        await expect(appMarketReputation.connect(operator).submitRating(appId, appVersion, reviewer, score, v, r, s))
            .to.emit(appMarketReputation, 'NewRating')
            .withArgs(appId, appVersion, reviewer, score);
    });

    it('addComment test | updateComment test | deleteComment test | submitCommentReaction test', async function () {
        const { appMarketReputation, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        
        // add comment test
        const domainOwner = signers[0];
        const reviewer = 'testUser.com';
        // to be a qualified address to submit complaint, the address should own a domain
        await terminusDIDProxy.register(domainOwner.address, {
            domain: reviewer,
            did: 'did',
            notes: 'local test for AppStore Reputaion contract',
            allowSubdomain: true
        })

        const domain = await getDomain(domainOwner, appMarketReputation.address);

        const types = getAddCommentTypes();

        const appId = 'myApp';
        const appVersion = '1'
        const content = 'I love the App very much';

        // register 1.myApp.app.myterminus.com
        const domain1 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
            domain: 'myApp.app.myterminus.com',
            did: 'did',
            notes: 'local test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        const domain2 = terminusDIDProxy.interface.encodeFunctionData('register', [operator.address, {
            domain: '1.myApp.app.myterminus.com',
            did: 'did',
            notes: 'local test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        await terminusDIDProxy.connect(operator).multicall([domain1, domain2]);

        // // The data to sign
        const value = {
            appId,
            appVersion,
            reviewer,
            content,
            nonce: await appMarketReputation.nonces(domainOwner.address)
        };

        let sig;
        sig = getVRSfromSig(await domainOwner._signTypedData(domain, types, value));
        
        const commentId = await appMarketReputation.getCommentId(appId, appVersion, reviewer, (await time.latestBlock()) + 1);
        
        await expect(appMarketReputation.connect(operator).addComment(appId, appVersion, reviewer, content, sig.v, sig.r, sig.s))
            .to.emit(appMarketReputation, 'CommentAdded')
            .withArgs(appId, appVersion, reviewer, commentId, content);
   
        // update comment test
        const updateCommentType = getUpdateCommentTypes();
        const contentUpdate = 'I love the App again';
        const updateCommentValue = {
            commentId,
            content: contentUpdate,
            nonce: await appMarketReputation.nonces(domainOwner.address)
        }
        sig = getVRSfromSig(await domainOwner._signTypedData(domain, updateCommentType, updateCommentValue));
        await expect(appMarketReputation.connect(operator).updateComment(commentId, contentUpdate, sig.v, sig.r, sig.s))
            .to.emit(appMarketReputation, 'CommentUpdated')
            .withArgs(commentId, contentUpdate);

        // submit comment reaction
        const reactionUser = signers[1];
        const reactionUserName = 'testUser1.com';
        await terminusDIDProxy.register(reactionUser.address, {
            domain: reactionUserName,
            did: 'did',
            notes: 'local test for AppStore Reputaion contract',
            allowSubdomain: true
        })
        const commentReactionType = getCommentReactionTypes();
        const commentReactionValue = {
            user: reactionUserName,
            commentId,
            reactionType: CommentReactionType.Like,
            nonce: await appMarketReputation.nonces(reactionUser.address)
        }
        sig = getVRSfromSig(await reactionUser._signTypedData(domain, commentReactionType, commentReactionValue));
        await expect(appMarketReputation.connect(operator).submitCommentReaction(reactionUserName, commentId, CommentReactionType.Like, sig.v, sig.r, sig.s))
            .to.emit(appMarketReputation, 'NewCommentReaction')
            .withArgs(reactionUserName, commentId, CommentReactionType.Like);

        // delete comment test
        const deleteCommentType = getDeleteCommentTypes();
        const deleteCommentValue = {
            commentId,
            nonce: await appMarketReputation.nonces(domainOwner.address)
        }
        sig = getVRSfromSig(await domainOwner._signTypedData(domain, deleteCommentType, deleteCommentValue));
        await expect(appMarketReputation.connect(operator).deleteComment(commentId, sig.v, sig.r, sig.s))
            .to.emit(appMarketReputation, 'CommentDeleted')
            .withArgs(commentId);
    });
});

async function getDomain(signer, contractAddr) {
    const chainId = await signer.getChainId();
    return {
        name: 'Terminus App Market Reputation',
        version: '1',
        chainId: chainId,
        verifyingContract: contractAddr
    };
}

function getRatingTypes() {
    return {
        Rating: [
            { name: 'appId', type: 'string' },
            { name: 'appVersion', type: 'string' },
            { name: 'reviewer', type: 'string' },
            { name: 'score', type: 'uint8' },
            { name: 'nonce', type: 'uint256' },
        ]
    };
}

function getAddCommentTypes() {
    return {
        AddComment: [
            { name: 'appId', type: 'string' },
            { name: 'appVersion', type: 'string' },
            { name: 'reviewer', type: 'string' },
            { name: 'content', type: 'string' },
            { name: 'nonce', type: 'uint256' },
        ]
    };
}

function getUpdateCommentTypes() {
    return {
        UpdateComment: [
            { name: 'commentId', type: 'bytes32' },
            { name: 'content', type: 'string' },
            { name: 'nonce', type: 'uint256' },
        ]
    };
}

function getDeleteCommentTypes() {
    return {
        DeleteComment: [
            { name: 'commentId', type: 'bytes32' },
            { name: 'nonce', type: 'uint256' },
        ]
    };
}

function getCommentReactionTypes() {
    return {
        CommentReaction: [
            { name: 'user', type: 'string'},
            { name: 'commentId', type: 'bytes32' },
            { name: 'reactionType', type: 'uint8' },
            { name: 'nonce', type: 'uint256' },
        ]
    };
}

// function getCommentIdTypes() {
//     return {
//         CommentId: [
//             { name: 'appId', type: 'string' },
//             { name: 'appVersion', type: 'string' },
//             { name: 'reviewer', type: 'string' },
//             { name: 'blockNumber', type: 'uint256' },
//         ]
//     };
// }

function getVRSfromSig(sig) {
    return {
        v: parseInt(sig.substring(130, 132), 16),
        r: '0x' + sig.substring(2, 66),
        s: '0x' + sig.substring(66, 130)
    }
}