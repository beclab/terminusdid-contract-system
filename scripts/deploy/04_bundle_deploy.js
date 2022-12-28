const {ethers} = require("hardhat");

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

   const BundleRegistry = await ethers.getContractFactory('BundleRegistry');
   console.log("Deploying...")

   const id_address = deployments["IdRegistry"];
   const name_address = deployments["NameRegistry"];

   const registry = await BundleRegistry.deploy(id_address, name_address, deployer.address);
       
   await sleep(1000*30);
   console.log("BundleRegistry address", registry.address)
   console.log("Waiting for deployed...")

    await run("verify:verify", {
        address: registry.address,
        constructorArguments: [
            id_address,
            name_address,
            deployer.address
        ],
    });

    await sleep(1000*50);

    deployments["BundleRegistry"] = registry.address;
    await new Promise((resolve,reject) => {
        fs.writeFile('./deployments/deployments.json',JSON.stringify(deployments), function(err){
            if(err){
                console.log(err)
                return resolve(err);
            }
            return resolve();
        })
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

    if( 'BundleRegistry' in deployments ) {
        return;
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();

  