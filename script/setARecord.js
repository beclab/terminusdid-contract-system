const { ethers } = require("hardhat");
const config = require("../hardhat.config");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const rootResolverAddr = config.addresses.rootResolver;
    const rootResolver = await ethers.getContractAt("RootResolver", rootResolverAddr, deployer);

    let tx;

    tx = await rootResolver.setDnsARecord("song.net", "0xffffffaa")
    console.log(tx);
    confirm = await tx.wait();
    console.log(confirm);
    console.log(confirm.transactionHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
