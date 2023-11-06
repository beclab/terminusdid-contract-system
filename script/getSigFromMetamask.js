const { MetaMaskSDK } = require('@metamask/sdk');
const qrcode = require('qrcode-terminal');

const SignatureAlogorithm = {
    ECDSA: 0,
};

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
                { name: 'expiredAt', type: 'uint256' }
            ]
        },
        primaryType: 'AuthAddressReq',
        domain: {
            name: 'DID',
            version: '1',
            chainId: 5,
            verifyingContract: "0xeDd7686113352C145e1757Ee8e48c2e495ebE59E"
        },
        message: {
            addr: "0x40688b08ef03a5250706f6E120cb24Dfb5601B70",
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "new.world",
            expiredAt: 1762566877
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
