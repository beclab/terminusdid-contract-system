const { ethers, upgrades } = require("hardhat");

var fs = require('fs');

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
        return console.error(`MyMinimalForwarder has not deployed yet!\n`)
    }

    const NameRegistry = await ethers.getContractFactory('NameRegistry');
    console.log("Deploying...")
    const proxy = await upgrades.deployProxy(
        NameRegistry,
        ["Farcaster NameRegistry", "FCN", deployer.address, deployer.address],
        {
            initializer: 'initialize',
            kind: 'uups',
            constructorArgs: [myMinimalForwarderAddr],
            unsafeAllow: ["constructor"]
        }
    )

    console.log("Waiting for deployed...")
    await proxy.deployed();

    console.log("Proxy address", proxy.address)

    const implAddress = await upgrades.erc1967.getImplementationAddress(proxy.address)
    console.log("Implementation address", implAddress)

    deployments["NameRegistry"] = proxy.address;
    deployments["NameRegistry_Implementation"] = implAddress;
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
            address: proxy.address,
            constructorArguments: [
                myMinimalForwarderAddr
            ]
        });
    } catch (error) {
        console.log(error)
    }
}


async function start() {
    console.log(`03: deploy NameResigtry ...\n`);
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

    if ('NameRegistry' in deployments) {
        return console.log(`NameRegistry has deployed!\n`)
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();

