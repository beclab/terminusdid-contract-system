var fs = require('fs');
const {ethers} = require("hardhat");
//const deployments = require("")
//const file = await open('../../deployments/deployments');

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

    const IdRegistry = await ethers.getContractFactory('IdRegistry');
    console.log("Deploying...")
    const registry = await IdRegistry.deploy(myMinimalForwarderAddr);
        
    console.log("IdRegistry address", registry.address)
    console.log("Waiting for deployed...")
    
    await sleep(1000*50);

    deployments["IdRegistry"] = registry.address;
    await new Promise((resolve,reject) => {
        fs.writeFile('./deployments/deployments.json',JSON.stringify(deployments), function(err){
            if(err){
                console.log(err)
                return resolve(err);
            }
            return resolve();
        })
    });

    await run("verify:verify", {
        address: registry.address,
        constructorArguments: [
            myMinimalForwarderAddr
        ],
    });
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

    if( 'IdRegistry' in deployments ) {
        return;
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();