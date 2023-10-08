const { ethers } = require("hardhat");
const config = require("../hardhat.config");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const rootResolverAddr = config.addresses.rootResolver;
    const rootResolver = await ethers.getContractAt("RootResolver", rootResolverAddr, deployer);

    let tx;
    // prerequisites:
    // 1. domain song.net should exists
    // 2. signer should be owner of domain song.net or owner of its parent domains.
    tx = await rootResolver.setRsaPubKey("song.net", "0x305c300d06092a864886f70d0101010500034b003048024100b488bcd257208e7f5906b398a8513ee7e7eaf32ff762af854850afaead8816c8083a26f04ae1a947baad05b3318506d43802a9116bf3c8f1ec31fb885c4ea84d0203010001");
    console.log(tx);
    confirm = await tx.wait();
    console.log(confirm);
    console.log(confirm.transactionHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
