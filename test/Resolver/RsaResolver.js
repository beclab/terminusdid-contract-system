const crypto = require('crypto');
var NodeRSA = require('node-rsa');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { BigNumber, getContractFactory } = ethers;

describe('RsaPubKeyResolver test', function () {

    async function deployTokenFixture() {

        const RsaPubKeyResolver = await getContractFactory('RsaPubKeyResolver');
        const rsaPubKeyResolver = await RsaPubKeyResolver.deploy();
        await rsaPubKeyResolver.deployed();

        return { rsaPubKeyResolver };
    }

    async function canParseRsaPubKeyWithDifferentLength(length) {
        const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
        const { publicKey, _ } = crypto.generateKeyPairSync("rsa", {
            modulusLength: length,
        });
        const pubKeyDer = publicKey.export({ type: 'pkcs1', format: 'der' });
        const pubKeyJwt = publicKey.export({ type: 'pkcs1', format: 'jwk' });

        const modulusFromJwk = '0x' + Buffer.from(pubKeyJwt.n, 'base64').toString('hex');
        const publicExponentFromJwk = BigNumber.from('0x' + Buffer.from(pubKeyJwt.e, 'base64').toString('hex'));

        // get m and e from contract
        const { modulus, publicExponent } = await rsaPubKeyResolver.parse(pubKeyDer);

        expect(modulus).to.equal(modulusFromJwk);
        expect(publicExponent).to.equal(publicExponentFromJwk);
    }

    it('contract can parse rsa pubkey to the same result with nodejs crypto package', async function () {
        let testTimes = 10;
        while (testTimes--) {
            await canParseRsaPubKeyWithDifferentLength(1024);
            await canParseRsaPubKeyWithDifferentLength(2048);
            await canParseRsaPubKeyWithDifferentLength(4096);
        }
    });

    describe('invalid pubKey test', async function () {
        it('valid pubKey', async function () {
            const pubKeyDer = Buffer.from('3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            key.importKey(pubKeyDer, 'pkcs1-public-der');

            const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
            const { modulus, publicExponent } = await rsaPubKeyResolver.parse(pubKeyDer);

            expect(modulus).to.equal('0x' + key.keyPair.n.toString(16));
            expect(publicExponent).to.equal(BigNumber.from(key.keyPair.e));
        });

        it('invalid sequence length', async function () {
            const pubKeyDer = Buffer.from('3083010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x82');

            const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
            await expect(rsaPubKeyResolver.parse(pubKeyDer)).to.be.revertedWith('Input bytes string is too short');
        });

        it('invalid sequence type', async function () {
            const pubKeyDer = Buffer.from('4083010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
            await expect(rsaPubKeyResolver.parse(pubKeyDer)).to.be.revertedWith('Not type SEQUENCE STRING');
        });

        it('invalid modulus type', async function () {
            const pubKeyDer = Buffer.from('3082010a0382010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x3');

            const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
            await expect(rsaPubKeyResolver.parse(pubKeyDer)).to.be.revertedWith('Not type INTEGER');
        });

        it('invalid publicExponent type', async function () {
            const pubKeyDer = Buffer.from('3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0303010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x3');

            const { rsaPubKeyResolver } = await loadFixture(deployTokenFixture);
            await expect(rsaPubKeyResolver.parse(pubKeyDer)).to.be.revertedWith('Not type INTEGER');
        });
    });
});