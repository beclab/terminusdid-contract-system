const {ethers, upgrades} = require("hardhat");

var fs = require('fs');

function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
}

async function main(deployments) {
    
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const myMinimalForwarderAddr = deployments.MyMinimalForwarder;
    if (!myMinimalForwarderAddr) {
        return;
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
            unsafeAllow : ["constructor"] 
        }
    )

    console.log("Proxy address", proxy.address)
    console.log("Waiting for deployed...")
    await proxy.deployed();

    await sleep(1000*10);

    const implAddress = await upgrades.erc1967.getImplementationAddress(proxy.address)
    console.log("Implementation address", implAddress)

    deployments["NameRegistry"] = proxy.address;
    deployments["NameRegistry_Implementation"] = implAddress;
    await new Promise((resolve,reject) => {
        fs.writeFile('./deployments/deployments.json',JSON.stringify(deployments), function(err){
            if(err){
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
    const result = await new Promise((resolve,reject) => {
        fs.readFile('./deployments/deployments.json',function(err,data){
            if(err){
                console.log(err)
                return resolve(null);
            }
            return resolve(data);
        })
    });

    if( !result) {
        return;
    }

    let deployments = JSON.parse(result);
    console.log(deployments)

    if( 'NameRegistry' in deployments ) {
        return;
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();

 