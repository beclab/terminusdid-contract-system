const { ethers, network } = require("hardhat");
const config = require("../../hardhat.config");
const { utils } = ethers;
const SignatureAlogorithm = {
    ECDSA: 0,
};
const Action = {
    Add: 0,
    Remove: 1,
}

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const chainId = await deployer.getChainId();
    
    const rootTaggerAddr = config.addresses[network.name].rootTagger;
    
    const domain = {
        name: 'Terminus DID Root Tagger',
        version: '1',
        chainId: chainId,
        verifyingContract: rootTaggerAddr
    };

    console.log(domain)

    const types = {
        AuthAddressReq: [
            { name: 'addr', type: 'address' },
            { name: 'algorithm', type: 'uint8' },
            { name: 'domain', type: 'string' },
            { name: 'signAt', type: 'uint256' },
            { name: 'action', type: 'uint8' },
        ]
    };

    const value = {
        addr: "0xc4A33d8A9ef964c71424D3D40a092346FdC01cE9",
        algorithm: SignatureAlogorithm.ECDSA,
        domain: "song.net",
        signAt: 1703048699,
        action: Action.Add
    }

    console.log(value);

    const DOMAIN_SEPARATOR = utils._TypedDataEncoder.hashDomain(domain, types, value);
    console.log(`domain separator: ${DOMAIN_SEPARATOR}`);

    const signingMsg = utils._TypedDataEncoder.encode(domain, types, value);
    console.log(`msg to be sig: ${signingMsg}`);

    const signingMsgHash = utils._TypedDataEncoder.hash(domain, types, value);
    console.log(`msg hash to be sig: ${signingMsgHash}`);

    const sigFromDomainOwner = await deployer._signTypedData(domain, types, value);
    console.log(`sig: ${sigFromDomainOwner}`);
}

main().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
