const { ethers, network } = require('hardhat');
const config = require('../../hardhat.config');

const CommentReactionType = {
    Cancel: 0,
    Like: 1,
    Dislike: 2
};

async function main() {
    const [manager, reviewer] = await ethers.getSigners();
    console.log('manager account:', manager.address);
    console.log('account balance:', (await manager.getBalance()).toString());

    console.log('reviewer account:', reviewer.address);
    console.log('account balance:', (await reviewer.getBalance()).toString());

    let tx;
    let confirm;

    let value;
    let sig;
    let types;

    let maxFeePerGas = ethers.BigNumber.from(1000000000) // default to 1 gwei
    let maxPriorityFeePerGas = ethers.BigNumber.from(1000000000) // default to 1 gwei

    const terminusDIDProxyAddr = config.addresses[network.name].terminusDIDProxy;
    const terminusDIDProxy = await ethers.getContractAt('TerminusDID', terminusDIDProxyAddr, manager);

    const appStoreReputationAddr = config.addresses[network.name].appStoreReputation;
    const appStoreReputation = await ethers.getContractAt('AppStoreReputation', appStoreReputationAddr, manager);

    const tagsFrom = 'app.myterminus.com';

    // register a test app
    let appId = 'TestApp';
    let appVersion = '1';

    let appFullName = `${appVersion}.${appId}.${tagsFrom}`;

    if (!(await terminusDIDProxy.isRegistered(appFullName))) {
        const domain1 = terminusDIDProxy.interface.encodeFunctionData('register', [manager.address, {
            domain: `${appId}.${tagsFrom}`,
            did: 'did',
            notes: 'test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        const domain2 = terminusDIDProxy.interface.encodeFunctionData('register', [manager.address, {
            domain: appFullName,
            did: 'did',
            notes: 'test for AppStore Reputation contract',
            allowSubdomain: true
        }]);
        tx = await terminusDIDProxy.connect(manager).multicall([domain1, domain2], {
            maxFeePerGas,
            maxPriorityFeePerGas
        });
        confirm = await tx.wait();
        console.log(`registered test app ${appFullName}: ${confirm.transactionHash}`);
    } else {
        console.log(`${appFullName} has registered`);
    }

    // submit a rating to 1.TestApp.app.myterminus.com from song.net
    let reviewerName = 'song.net';
    let reviewerOwner = '0x945e9704D2735b420363071bB935ACf2B9C4b814';

    const domain = await getDomain(reviewer, appStoreReputation.address);
    types = getRatingTypes();
    const score = 5;

    value = {
        appId,
        appVersion,
        reviewer: reviewerName,
        score,
        nonce: await appStoreReputation.nonces(reviewerOwner)
    };

    sig = await reviewer._signTypedData(domain, types, value);
    let {v, r, s} = getVRSfromSig(sig);

    tx = await appStoreReputation.connect(manager).submitRating(appId, appVersion, reviewerName, score, v, r, s, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    confirm = await tx.wait();
    console.log(`submit a rating ${score} to ${appFullName} from ${reviewerName}: ${confirm.transactionHash}`);

    // add comment
    types = getAddCommentTypes();
    const content = 'I love the App very much';

    value = {
        appId,
        appVersion,
        reviewer: reviewerName,
        content,
        nonce: await appStoreReputation.nonces(reviewerOwner)
    };

    sig = getVRSfromSig(await reviewer._signTypedData(domain, types, value));
    tx = await appStoreReputation.connect(manager).addComment(appId, appVersion, reviewerName, content, sig.v, sig.r, sig.s, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    confirm = await tx.wait();
    console.log(`add a comment <${content}> to ${appFullName} from ${reviewerName}: ${confirm.transactionHash}`);

    // update comment
    let log = confirm.logs[0];
    let logData = ethers.utils.defaultAbiCoder.decode(
        ['string', 'string', 'string', 'bytes32', 'string'],
        log.data
     );
    let commentId = logData[3];
    console.log(`comment id: ${commentId}`);

    types = getUpdateCommentTypes();
    let contentUpdate = 'I love the App again';
    value = {
        commentId,
        content: contentUpdate,
        nonce: await appStoreReputation.nonces(reviewerOwner)
    }
    sig = getVRSfromSig(await reviewer._signTypedData(domain, types, value));
    tx = await appStoreReputation.connect(manager).updateComment(commentId, contentUpdate, sig.v, sig.r, sig.s, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });

    confirm = await tx.wait();
    console.log(`update comment <${contentUpdate}> to comment ${commentId} of ${appFullName} from ${reviewerName}: ${confirm.transactionHash}`);

    // comment reaction
    types = getCommentReactionTypes();
    value = {
        user: reviewerName,
        commentId,
        reactionType: CommentReactionType.Like,
        nonce: await appStoreReputation.nonces(reviewerOwner)
    }
    sig = getVRSfromSig(await reviewer._signTypedData(domain, types, value));
    tx = await appStoreReputation.connect(manager).submitCommentReaction(reviewerName, commentId, CommentReactionType.Like, sig.v, sig.r, sig.s, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    confirm = await tx.wait();
    console.log(`add a comment reaction <${CommentReactionType.Like}> to comment ${commentId} of ${appFullName} from ${reviewerName}: ${confirm.transactionHash}`);

    // delete comment
    types = getDeleteCommentTypes();
    value = {
        commentId,
        nonce: await appStoreReputation.nonces(reviewerOwner)
    }
    sig = getVRSfromSig(await reviewer._signTypedData(domain, types, value));
    tx = await appStoreReputation.connect(manager).deleteComment(commentId, sig.v, sig.r, sig.s, {
        maxFeePerGas,
        maxPriorityFeePerGas
    });
    console.log(`delete comment ${commentId} of ${appFullName} from ${reviewerName}: ${confirm.transactionHash}`);
}

async function getDomain(signer, contractAddr) {
    const chainId = await signer.getChainId();
    return {
        name: 'Terminus App Store Reputation',
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
            { name: 'user', type: 'string' },
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

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});

