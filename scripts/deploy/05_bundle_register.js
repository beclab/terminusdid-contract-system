const {ethers} = require("hardhat");
const getDefaultProvider = require("../helpers/getDefaultEthersProvider").getDefaultProvider;
//const getSigner = require("../helpers/getDefaultEthersProvider").getSigner;


var fs = require('fs');

function sleep(ms) {
    return new Promise((resolve) => {
      setTimeout(resolve, ms);
    });
}

const provider = getDefaultProvider("goerli");
//const signer = getSigner("goerli", provider);

async function main(deployments) {
    
   const [deployer] = await ethers.getSigners();
   console.log("Deploying contracts with the account:", deployer.address);
   console.log("Account balance:", (await deployer.getBalance()).toString());

   let ADMIN_ROLE = "0xa49807205ce4d355092ef5a8a18f56e8913cf4a201fbe287825b095693c21775";

   const BundleRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/BundleRegistry.sol/BundleRegistry.json', 'utf8'));
   const BundleRegistry = new ethers.Contract(deployments.BundleRegistry, BundleRegistryArtifacts.abi, provider);

   const IdRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/IdRegistry.sol/IdRegistry.json', 'utf8'));
   const IdRegistry = new ethers.Contract(deployments.IdRegistry, IdRegistryArtifacts.abi, provider);

   const NameRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/NameRegistry.sol/NameRegistry.json', 'utf8'));
   const NameRegistry = new ethers.Contract(deployments.NameRegistry, NameRegistryArtifacts.abi, provider);
   

    await IdRegistry.connect(deployer).changeTrustedCaller(BundleRegistry.address, {
            gasPrice: ethers.utils.parseUnits("10", "gwei"),
            gasLimit: 1500000,
    });


    await NameRegistry.connect(deployer).grantRole(ADMIN_ROLE, deployer.address, {
            gasPrice: ethers.utils.parseUnits("10", "gwei"),
            gasLimit: 1500000,
    });

    await NameRegistry.connect(deployer).changeTrustedCaller(BundleRegistry.address, {
        gasPrice: ethers.utils.parseUnits("10", "gwei"),
        gasLimit: 1500000,
    });

    await NameRegistry.connect(deployer).renounceRole(ADMIN_ROLE, deployer.address, {
        gasPrice: ethers.utils.parseUnits("10", "gwei"),
        gasLimit: 1500000,
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

    
    main(deployments).catch((error) => {
        console.error(error);
        process.exitCode = 1;
    });
}

start();

  