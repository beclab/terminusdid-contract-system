const assert = require("assert");
const { ethers } = require("hardhat");
const fetch = require("node-fetch");
const keythereum = require("keythereum");

const botKeyStore = require("../wallets/BotKeyStore.json");
const terminusDIDAbiJson = require("../out/TerminusDID.sol/TerminusDID.json")

let terminusDIDProxy;

async function main() {
    // provider
    const NODE_URL = "https://sepolia.optimism.io";
    const provider = new ethers.providers.JsonRpcProvider(NODE_URL);

    // init bot wallet
    const botPrivKey = keythereum.recover(botKeyStore.password, botKeyStore);
    const botWallet = new ethers.Wallet(botPrivKey, provider);
    assert(botWallet.address.toLowerCase() === ("0x" + botKeyStore.address).toLowerCase(), "wallet decryption failed!");

    // print chain info and bot balance
    const chainId = await botWallet.getChainId();
    console.log(`connected with chain: ${chainId}`);
    const botBalance = await botWallet.getBalance();
    console.log(`wallet ${botWallet.address} balance: ${ethers.utils.formatEther(botBalance)} eth`);

    // init terminusDID and print metainfo of contract
    const TERMINUSDIDPROXY = "0x4c8c98e652d6a01494971a8faF5d3b68338f9ED4";
    terminusDIDProxy = new ethers.Contract(TERMINUSDIDPROXY, terminusDIDAbiJson.abi, botWallet);
    const name = await terminusDIDProxy.name();
    const symbol = await terminusDIDProxy.symbol();
    let supply = await terminusDIDProxy.totalSupply();
    console.log(`connected with contract ${terminusDIDProxy.address}, name - ${name}, symbol - ${symbol}`);
    console.log(`contract has ${supply} domains be registerd`);
    
    // get old registered domain fro api
    const registeredDomain = await getRegisteredDomain();

    // register
    for (let [index, domain] of registeredDomain.entries()) {
        await registerDomain(index, domain, 0);
    }
    
    supply = await terminusDIDProxy.totalSupply();
    console.log(`after migration, contract has ${supply} domains be registered`);
}

main();

async function getRegisteredDomain() {
    const url = "https://did-gate-v2.edge-dev.xyz/domain/faster_search_all";
    const response = await fetch(url);
    const jsonData = await response.json();
    return jsonData.data;
}

let tx;
let confirm;
let count = 0;
async function registerDomain(index, domain, level) {
    const isRegistered = await terminusDIDProxy.isRegistered(domain.name);
    console.log(`${"".padEnd(level)}record ${index} - ${domain.name}: ${isRegistered}`);
    if (!isRegistered) {
        // register
        console.log(`registering ${domain.name}...`);
        tx = await terminusDIDProxy.register(domain.owner, {
            domain: domain.name,
            did: domain.did,
            notes: domain.note,
            allowSubdomain: domain.allowSubdomain
        })
        confirm = await tx.wait(2);

        const checkRegistered = await terminusDIDProxy.isRegistered(domain.name);
        if (!checkRegistered) {
            console.error(`failed to register domain ${domain.name}`);
            return process.exit(1);
        }
        console.log(`migrate ${domain.name} successful #${count}`);
        count++;
    }

    if (domain.allowSubdomain && domain.subdomains.length > 0) {
        for (let [index, subdomain] of domain.subdomains.entries()) {
            await registerDomain(index, subdomain, level + 4);
        }
    }

}