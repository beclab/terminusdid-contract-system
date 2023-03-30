var fs = require('fs');
const { ethers } = require("hardhat");
//const deployments = require("")
//const file = await open('../../deployments/deployments');

// function sleep(ms) {
//     return new Promise((resolve) => {
//       setTimeout(resolve, ms);
//     });
// }

async function main(deployments) {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const myMinimalForwarderAddr = deployments.MyMinimalForwarder;
    if (!myMinimalForwarderAddr) {
        return console.error(`MyMinimalForwarder has not deployed yet!\n`);
    }

    const IdRegistry = await ethers.getContractFactory('IdRegistry');
    console.log("Deploying...");
    const registry = await IdRegistry.deploy(myMinimalForwarderAddr);
    console.log("Waiting for deployed...");
    await registry.deployed();

    console.log("IdRegistry address", registry.address);

    deployments["IdRegistry"] = registry.address;
    await new Promise((resolve, reject) => {
        fs.writeFile('./deployments/deployments.json', JSON.stringify(deployments), function (err) {
            if (err) {
                console.log(err)
                return resolve(err);
            }
            return resolve();
        })
    });

    try {
        await run("verify:verify", {
            address: registry.address,
            constructorArguments: [
                myMinimalForwarderAddr
            ],
        });
    } catch (err) {
        console.error(err);
    }
}


async function start() {
    console.log(`02: deploy IdResigtry ...\n`);
    const result = await new Promise((resolve, reject) => {
        fs.readFile('./deployments/deployments.json', function (err, data) {
            if (err) {
                console.log(err);
                return resolve(null);
            }
            return resolve(data);
        })
    });

    if (!result) {
        return console.error(`./deployments/deployments.json has not initialized yet`);
    }

    let deployments = JSON.parse(result);
    console.log(deployments);

    if ('IdRegistry' in deployments) {
        return console.log(`IdResigtry has deployed!\n`);
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();