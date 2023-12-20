require("hardhat");
const { MetaMaskSDK } = require('@metamask/sdk');
const qrcode = require('qrcode-terminal');
const config = require("../../hardhat.config");
const SignatureAlogorithm = {
    ECDSA: 0,
};
const Action = {
    Add: 0,
    Remove: 1,
}

const options = {
    shouldShimWeb3: false,
    dappMetadata: {
        name: 'DID auth address signatrue example',
        url: 'DID auth address signatrue example',
    },
    logging: {
        sdk: false,
    },
    checkInstallationImmediately: false,
    // Optional: customize modal text
    modals: {
        install: ({ link }) => {
            qrcode.generate(link, { small: true }, (qr) => console.log(qr));
            return {};
        },
        otp: () => {
            return {
                mount() { },
                updateOTPValue: (otpValue) => {
                    if (otpValue !== '') {
                        console.debug(
                            `[CUSTOMIZE TEXT] Choose the following value on your metamask mobile wallet: ${otpValue}`,
                        );
                    }
                },
            };
        },
    },
};

const sdk = new MetaMaskSDK(options);

const start = async () => {
    console.debug(`start NodeJS example`);

    const accounts = await sdk.connect();
    console.log('connect request accounts', accounts);


    const ethereum = sdk.getProvider();
    console.log(`selected address: ${ethereum.selectedAddress}`);

    const rootTaggerAddr = config.addresses.op_sepolia.rootResolver;

    const msgParams = {
        types: {
            EIP712Domain: [
                { name: 'name', type: 'string' },
                { name: 'version', type: 'string' },
                { name: 'chainId', type: 'uint256' },
                { name: 'verifyingContract', type: 'address' },
            ],
            AuthAddressReq: [
                { name: 'addr', type: 'address' },
                { name: 'algorithm', type: 'uint8' },
                { name: 'domain', type: 'string' },
                { name: 'signAt', type: 'uint256' },
                { name: 'action', type: 'uint8' },
            ]
        },
        primaryType: 'AuthAddressReq',
        domain: {
            name: 'DID',
            version: '1',
            chainId: 11155420,
            verifyingContract: rootTaggerAddr
        },
        message: {
            addr: "0x40688b08ef03a5250706f6E120cb24Dfb5601B70",
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "new.world",
            signAt: 1762566877,
            action: Action.Add
        },
    };

    const signResponse = await ethereum.request({
        method: 'eth_signTypedData_v4',
        params: [ethereum.selectedAddress, JSON.stringify(msgParams)],
    });

    console.log('eth_signTypedData_v4 response', signResponse);
};


start().catch((err) => {
    console.error(err);
});
