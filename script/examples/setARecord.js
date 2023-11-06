const { ethers, network } = require("hardhat");
const config = require("../../hardhat.config");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const rootTaggerAddr = config.addresses[network.name].rootTagger;
    const rootTagger = await ethers.getContractAt("RootTagger", rootTaggerAddr, deployer);

    let tx;
    // prerequisites:
    // 1. domain song.net should exists
    // 2. signer should be owner of domain song.net or owner of its parent domains or operator.
    tx = await rootTagger.setDnsARecord("song.net", "0xffffffaa")
    console.log(tx);
    confirm = await tx.wait();
    console.log(confirm);
    console.log(confirm.transactionHash);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
