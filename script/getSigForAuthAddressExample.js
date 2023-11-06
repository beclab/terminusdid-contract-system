const { ethers } = require("hardhat");

const { utils } = ethers;
const SignatureAlogorithm = {
    ECDSA: 0,
};

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Wallet account:", deployer.address);
    console.log("Account balance:", (await deployer.getBalance()).toString());

    const domain = {
        name: 'DID',
        version: '1',
        chainId: 5,
        verifyingContract: "0xeDd7686113352C145e1757Ee8e48c2e495ebE59E"
    };

    const types = {
        AuthAddressReq: [
            { name: 'addr', type: 'address' },
            { name: 'algorithm', type: 'uint8' },
            { name: 'domain', type: 'string' },
            { name: 'expiredAt', type: 'uint256' }
        ]
    };

    const value = {
        addr: "0x40688b08ef03a5250706f6E120cb24Dfb5601B70",
        algorithm: SignatureAlogorithm.ECDSA,
        domain: "sz.new.world",
        expiredAt: 1762566877
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
