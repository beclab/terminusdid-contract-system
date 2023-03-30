const { ethers } = require("hardhat");
// const getDefaultProvider = require("../helpers/getDefaultEthersProvider").getDefaultProvider;
//const getSigner = require("../helpers/getDefaultEthersProvider").getSigner;


var fs = require('fs');

// function sleep(ms) {
//     return new Promise((resolve) => {
//       setTimeout(resolve, ms);
//     });
// }

// const provider = getDefaultProvider("goerli");
// //const signer = getSigner("goerli", provider);

async function main(deployments) {

    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    let ADMIN_ROLE = "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775";

    let bot_address = "0xb3e01824be3079b982fefb2c5e5f79fe150eac3d";

    if (!deployments.BundleRegistry || !deployments.IdRegistry || !deployments.NameRegistry) {
        return console.error(`dependent contracts has not deployed yet`);
    }

    const BundleRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/BundleRegistry.sol/BundleRegistry.json', 'utf8'));
    const BundleRegistry = new ethers.Contract(deployments.BundleRegistry, BundleRegistryArtifacts.abi, deployer);

    const IdRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/IdRegistry.sol/IdRegistry.json', 'utf8'));
    const IdRegistry = new ethers.Contract(deployments.IdRegistry, IdRegistryArtifacts.abi, deployer);

    const NameRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/NameRegistry.sol/NameRegistry.json', 'utf8'));
    const NameRegistry = new ethers.Contract(deployments.NameRegistry, NameRegistryArtifacts.abi, deployer);

    let tx;
    let confirm;
    console.log(`IdRegistry: change trustedCaller to ${BundleRegistry.address} ...`);
    tx = await IdRegistry.connect(deployer).changeTrustedCaller(BundleRegistry.address);
    confirm = await tx.wait();
    console.log(`transaction ${confirm.transactionHash} succeed with gasUsed ${confirm.gasUsed}`);

    console.log(`NameRegistry: grand admin role to ${deployer.address} ...`);
    tx = await NameRegistry.connect(deployer).grantRole(ADMIN_ROLE, deployer.address);
    confirm = await tx.wait();
    console.log(`transaction ${confirm.transactionHash} succeed with gasUsed ${confirm.gasUsed}`);

    console.log(`NameRegistry: change trustedCaller to ${BundleRegistry.address} ...`);
    tx = await NameRegistry.connect(deployer).changeTrustedCaller(BundleRegistry.address);
    confirm = await tx.wait();
    console.log(`transaction ${confirm.transactionHash} succeed with gasUsed ${confirm.gasUsed}`);

    console.log(`NameRegistry: renounce admin role from ${deployer.address} ...`);
    tx = await NameRegistry.connect(deployer).renounceRole(ADMIN_ROLE, deployer.address);
    confirm = await tx.wait();
    console.log(`transaction ${confirm.transactionHash} succeed with gasUsed ${confirm.gasUsed}`);

    console.log(`BundleRegistry: change trustedCaller to ${bot_address} ...`);
    tx = await BundleRegistry.connect(deployer).changeTrustedCaller(bot_address);
    confirm = await tx.wait();
    console.log(`transaction ${confirm.transactionHash} succeed with gasUsed ${confirm.gasUsed}`);
}

async function start() {
    console.log(`05: config system ...\n`);
    const result = await new Promise((resolve, reject) => {
        fs.readFile('./deployments/deployments.json', function (err, data) {
            if (err) {
                console.log(err)
                return resolve(null);
            }
            return resolve(data);
        })
    });

    if (!result) {
        return console.error(`./deployments/deployments.json has not initialized yet`);
    }

    let deployments = JSON.parse(result);
    console.log(deployments)


    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();

