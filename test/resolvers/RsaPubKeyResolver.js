const crypto = require('crypto');
var NodeRSA = require('node-rsa');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');
const { register } = require('module');

const { BigNumber, utils, constants, getContractFactory, getSigners } = ethers;
const { AddressZero } = constants;

describe('RsaPubKey test', function () {
    async function deployTokenFixture() {
        const [deployer] = await getSigners();
        const operator = deployer;

        let Registrar = await getContractFactory('Registrar');
        let registrar = await Registrar.deploy(AddressZero, AddressZero, operator.address);
        await registrar.deployed();

        let TerminusDID = await getContractFactory('TerminusDID');
        const name = "TerminusDID";
        const symbol = "TDID";

        let terminusDIDProxy = await upgrades.deployProxy(TerminusDID, [name, symbol], { initializer: 'initialize', kind: 'uups', constructorArgs: [], unsafeAllow: ['state-variable-immutable'] })
        await terminusDIDProxy.deployed();

        await terminusDIDProxy.setRegistrar(registrar.address);

        const RootResolver = await getContractFactory('RootResolver');
        const rootResolver = await RootResolver.deploy(registrar.address, terminusDIDProxy.address, operator.address);
        await rootResolver.deployed();

        await registrar.setRegistry(terminusDIDProxy.address);
        await registrar.setRootResolver(rootResolver.address);

        return { rootResolver, registrar, operator };
    }

    async function canParseRsaPubKeyWithDifferentLength(length) {
        const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
        const { publicKey, _ } = crypto.generateKeyPairSync("rsa", {
            modulusLength: length,
        });
        const pubKeyDer = publicKey.export({ type: 'pkcs1', format: 'der' });

        await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        // set and get pubKey from contract
        await rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer);
        const pubKeyDerRet = await rootResolver.rsaPubKey("a");
        expect(pubKeyDerRet.slice(2)).to.equal(pubKeyDer.toString("hex"));
    }

    it('contract has same result with nodejs crypto package', async function () {
        let testTimes = 5;
        while (testTimes--) {
            await canParseRsaPubKeyWithDifferentLength(1024);
            await canParseRsaPubKeyWithDifferentLength(2048);
            await canParseRsaPubKeyWithDifferentLength(4096);
        }
    });

    describe('invalid pubKey test', async function () {
        it('valid pubKey', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            key.importKey(pubKeyDer, 'pkcs1-public-der');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer);
            const pubKeyDerRet = await rootResolver.rsaPubKey("a");
            expect(pubKeyDerRet.slice(2)).to.equal(pubKeyDer.toString("hex"));
        });

        it('invalid sequence length', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('3083010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x82');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWithCustomError(rootResolver, "Asn1DecodeError")
        });

        it('invalid sequence type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('4083010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWithCustomError(rootResolver, "Asn1DecodeError")
        });

        it('invalid modulus type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('3082010a0382010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0203010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x3');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWithCustomError(rootResolver, "Asn1DecodeError")
        });

        it('invalid publicExponent type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('3082010a0282010100cce13bf3a77cbf0c407d734d3e646e24e4a7ed3a6013a191c4c58c2d3fa39864f34e4d3880a4c442905cfcc0570016f36a23e40b2372a95449203d5667170b78d5fba9dbdf0d045970dfed75764d9107e2ec3b09ff2087996c84e1d7aafb2e15dcce57ee9a5deb067ba65b50a382176ff34c9b0722aaff90e5e4ff7b915c89134e8d43555638e809d12d9795eebf36c39f7b57a400564250f60d969440f540ea34d25fc7cbbd8000731f5247ab3a408e7864b0b1afce5eb9d337601c0df36a1832b10374bca8a0325e2b56dca4f179c545002fa1d25b7fde737b48fdd3187b713e1b1f0cec601db09840b28cb56051945892e9141a0ba72900670cc8a587368f0303010001', 'hex');

            var key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs1-public-der')).to.throw('Expected 0x2: got 0x3');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWithCustomError(rootResolver, "Asn1DecodeError")
        });
    });
});