const crypto = require('crypto');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { utils, getContractFactory } = ethers;

describe('RsaResolver test', function () {

    async function deployTokenFixture() {

        const Oracle = await getContractFactory('Oracle');
        const oracle = await Oracle.deploy();
        await oracle.deployed();

        const PublicResolver = await getContractFactory('PublicResolver');
        const publicResolver = await PublicResolver.deploy(oracle.address);
        await publicResolver.deployed();

        await oracle.addResolver(publicResolver.address);
        return { publicResolver, oracle };
    }

    describe('Basis test', function () {
        it('oracle check', async function () {
            const { publicResolver, oracle } = await loadFixture(deployTokenFixture);
            const oracleAddr = await publicResolver.oracle();
            expect(oracleAddr).to.equal(oracle.address);
        });

        it('set/get rsa pub key', async function () {
            const { publicResolver } = await loadFixture(deployTokenFixture);
            const { publicKey, privateKey } = crypto.generateKeyPairSync("rsa", {
                // The standard secure default length for RSA keys is 2048 bits
                modulusLength: 2048,
                publicKeyEncoding: {
                    type: 'pkcs1',
                    format: 'pem'
                },
                privateKeyEncoding: {
                    type: 'pkcs1',
                    format: 'pem'
                },
            })
            const domain = "test.com";
            const node = utils.keccak256(utils.toUtf8Bytes(domain));
            await publicResolver.setRsaPubKey(node, publicKey);

            const pubKeyFromChain = await publicResolver.getRsaPubKey(node);
            expect(publicKey).to.equal(pubKeyFromChain);

            // encrypt with pubKeyFromChain and decrypt with privateKey
            const dataToEncrypt = "hello did service";

            const encryptedData = crypto.publicEncrypt(
                {
                    key: pubKeyFromChain,
                    padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                    oaepHash: 'sha256',
                },
                // We convert the data string to a buffer using `Buffer.from`
                Buffer.from(dataToEncrypt)
            )

            const decryptedData = crypto.privateDecrypt(
                {
                    key: privateKey,
                    // In order to decrypt the data, we need to specify the
                    // same hashing function and padding scheme that we used to
                    // encrypt the data in the previous step
                    padding: crypto.constants.RSA_PKCS1_OAEP_PADDING,
                    oaepHash: 'sha256',
                },
                Buffer.from(encryptedData, 'base64'),
            )
            expect(dataToEncrypt).to.equal(decryptedData.toString());
        });
    })
});