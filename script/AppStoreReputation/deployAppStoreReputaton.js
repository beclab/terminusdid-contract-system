const { ethers, network } = require("hardhat");
const config = require("../../hardhat.config");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    let tx;
    let confirm;

    const terminusDIDProxyAddr = config.addresses[network.name].terminusDIDProxy;
    const terminusDIDProxy = await ethers.getContractAt("TerminusDID", terminusDIDProxyAddr, deployer);

    let operator = deployer;

    const tagsFrom = 'app.myterminus.com';
    const tagName = 'ratings';

    const hasDomain = await terminusDIDProxy.isRegistered(tagsFrom);
    if (!hasDomain) {

        // 'myterminus.com' has been register already, just need to register 'app.myterminus.com'
        await terminusDIDProxy.connect(operator).register(operator.address, {
            domain: 'app.myterminus.com',
            did: 'did',
            notes: 'testnet chain for AppStore Reputation contract',
            allowSubdomain: true
        });
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
    const ratingType = ethers.utils.arrayify('0x04060002030101');
    const fieldNames = new Array();
    fieldNames.push(['reviewer', 'score']);
    tx = await terminusDIDProxy.connect(operator).defineTag(tagsFrom, tagName, ratingType, fieldNames);
    confirm = await tx.wait();
    console.log(`defined type Rating[]: ${confirm.transactionHash}`);

    const AppStoreReputation = await ethers.getContractFactory('AppStoreReputation');
    const appStoreReputation = await AppStoreReputation.deploy(terminusDIDProxy.address);
    await appStoreReputation.deployed();
    console.log(`deployed AppStoreReputation: ${appStoreReputation.address}`);
    
    await terminusDIDProxy.connect(operator).setTagger(tagsFrom, tagName, appStoreReputation.address);
    console.log(`set tagger to AppStoreReputation`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
