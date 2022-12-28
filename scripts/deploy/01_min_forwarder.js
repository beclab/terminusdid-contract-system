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

    const MyMinimalForwarder = await ethers.getContractFactory('MyMinimalForwarder');
    console.log("Deploying...")
    const myMinimalForwarder = await MyMinimalForwarder.deploy();

    console.log("MyMinimalForwarder address", myMinimalForwarder.address)
    console.log("Waiting for deployed...")
    
    await sleep(1000*10);

    deployments["MyMinimalForwarder"] = myMinimalForwarder.address;
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
            contract: "contracts/helpers/MyMinimalForwarder.sol:MyMinimalForwarder",
            address: myMinimalForwarder.address,
            constructorArguments: []
        });
    } catch (error) {
        console.log(error);
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

    if( 'MyMinimalForwarder' in deployments ) {
        return;
    }

    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();