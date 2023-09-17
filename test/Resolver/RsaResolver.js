const crypto = require('crypto');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { utils, getContractFactory } = ethers;

describe('RsaResolver test', function () {

    async function deployTokenFixture() {

        const RsaResolver = await getContractFactory('RsaResolver');
        const rsaResolver = await RsaResolver.deploy();
        await rsaResolver.deployed();

        return { rsaResolver };
    }

    describe('Basis test', function () {

        it('is valid pub key in DER bytes', async function () {
            const { rsaResolver } = await loadFixture(deployTokenFixture);
            const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
                // The standard secure default length for RSA keys is 2048 bits
                modulusLength: 2048,
            });

            const publicKeyInDER = publicKey.export({ type: 'pkcs1', format: 'der' });
            // const publicKeyInDER1 = publicKey.export({ type: 'spki', format: 'der' });
            // console.log(publicKeyInDER1.toString('hex'));
            const publicKeyInPEM = publicKey.export({ type: 'pkcs1', format: 'pem' });
            const publicKeyInJWK = publicKey.export({ format: 'jwk' });
            console.log(publicKeyInDER.toString('hex'));
            // console.log(publicKeyInPEM);
            // console.log(publicKeyInJWK);

            const n = Buffer.from(publicKeyInJWK.n, 'base64').toString('hex');
            const e = Buffer.from(publicKeyInJWK.e, 'base64').toString('hex');
            console.log(n);
            console.log(e);


            const privateKeyInDER = privateKey.export({ type: 'pkcs1', format: 'der' });
            const privateKeyInPEM = privateKey.export({ type: 'pkcs1', format: 'pem' });
            const privateKeyInJWK = privateKey.export({ format: 'jwk' });
            // console.log(privateKeyInDER.toString('hex'));
            // console.log(privateKeyInPEM);
            // console.log(privateKeyInJWK);

            const dataToEncrypt = "hello did service";

            const encryptedData = crypto.publicEncrypt(
                {
                    key: publicKeyInPEM,
                    padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                    oaepHash: 'sha256',
                },
                // We convert the data string to a buffer using `Buffer.from`
                Buffer.from(dataToEncrypt)
            )

            const decryptedData = crypto.privateDecrypt(
                {
                    key: privateKeyInPEM,
                    // In order to decrypt the data, we need to specify the
                    // same hashing function and padding scheme that we used to
                    // encrypt the data in the previous step
                    padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                    oaepHash: 'sha256',
                },
                Buffer.from(encryptedData, 'base64'),
            )
            // console.log(dataToEncrypt);
            // console.log(decryptedData.toString('utf8'));
            expect(dataToEncrypt).to.equal(decryptedData.toString('utf8'));
        });
    })
});