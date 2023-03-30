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

    const MyMinimalForwarder = await ethers.getContractFactory('MyMinimalForwarder');
    console.log("Deploying...")
    const myMinimalForwarder = await MyMinimalForwarder.deploy();
    console.log("Waiting for deployed...");
    await myMinimalForwarder.deployed();

    console.log("MyMinimalForwarder address", myMinimalForwarder.address)

    deployments["MyMinimalForwarder"] = myMinimalForwarder.address;
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
            contract: "contracts/helpers/MyMinimalForwarder.sol:MyMinimalForwarder",
            address: myMinimalForwarder.address,
            constructorArguments: []
        });
    } catch (error) {
        console.log(error);
    }
}


async function start() {
    console.log(`01: deploy min forwarder ...\n`);

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

    if ('MyMinimalForwarder' in deployments) {
        return console.log(`MyMinimalForwarder has deployed!\n`);
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();