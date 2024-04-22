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
            notes: '',
            allowSubdomain: true
        }, {
            maxFeePerGas,
            maxPriorityFeePerGas
        });
        console.log(`${tagsFrom} has been registered!`);
    } else {
        console.log(`${tagsFrom} is already registered!`);
    }

    /*
        struct · {
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

    const TerminusAppMarketReputation = await ethers.getContractFactory('TerminusAppMarketReputation');
    const appMarketReputation = await TerminusAppMarketReputation.deploy(terminusDIDProxy.address);
    await appMarketReputation.deployed();
    console.log(`deployed TerminusAppMarketReputation: ${appMarketReputation.address}`);

    await terminusDIDProxy.connect(operator).setTagger(tagsFrom, tagName, appMarketReputation.address);
    console.log(`set tagger to TerminusAppMarketReputation`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
