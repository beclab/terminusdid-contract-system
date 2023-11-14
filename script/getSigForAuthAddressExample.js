const { ethers } = require("hardhat");
const config = require("../hardhat.config");
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
    
    const rootResolverAddr = config.addresses.rootResolver;
    
    const domain = {
        name: 'DID',
        version: '1',
        chainId: 420,
        verifyingContract: rootResolverAddr
    };

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
        addr: "0x40688b08ef03a5250706f6E120cb24Dfb5601B70",
        algorithm: SignatureAlogorithm.ECDSA,
        domain: "new.world",
        signAt: 1762566877,
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
