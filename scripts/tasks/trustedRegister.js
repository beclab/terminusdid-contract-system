const {ethers} = require("hardhat");
const process = require("process");
const getDefaultProvider = require("../helpers/getDefaultEthersProvider").getDefaultProvider;
//const getSigner = require("../helpers/getDefaultEthersProvider").getSigner;


var fs = require('fs');

const provider = getDefaultProvider("goerli");

async function main(deployments) {

    console.log(process.argv)
    
   const [deployer] = await ethers.getSigners();
   
   const BundleRegistryArtifacts = JSON.parse(fs.readFileSync('./artifacts/contracts/BundleRegistry.sol/BundleRegistry.json', 'utf8'));
   const BundleRegistry = new ethers.Contract(deployments.BundleRegistry, BundleRegistryArtifacts.abi, provider);
 
   const to = "0xb636a68f834b4d75af9edc5fb0138bb4758ed293";
   const recovery = "0x0000000000000000000000000000000000000000";
   const url = "https://www.badiu.com/";
   const username = ethers.utils.formatBytes32String("test1").substring(0,34);
   const inviter = 0;

    await BundleRegistry.connect(deployer).trustedRegister(to, recovery, url, username , inviter, {
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

  