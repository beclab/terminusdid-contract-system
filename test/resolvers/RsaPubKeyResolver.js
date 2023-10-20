const crypto = require('crypto');
const NodeRSA = require('node-rsa');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { BigNumber, utils, constants, getContractFactory, getSigners } = ethers;
const { AddressZero } = constants;
const { keccak256, toUtf8Bytes } = utils;

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
        const pubKeyDer = publicKey.export({ type: 'spki', format: 'der' });

        await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        // set and get pubKey from contract
        await rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer);
        const pubKeyDerRet = await rootResolver.rsaPubKey(tokenId("a"));
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
        // generate rsa key pair online tool: https://www.lddgo.net/encrypt/rsakey
        it('valid pubKey', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const validPubKeyInPEM = `MFwwDQYJKoZIhvcNAQEBBQADSwAwSAJBAMCtKL288IuZLzrxWGlD7TeR7v0Zml2D
            OQXL2wGoJrJrZzXu/fTZZ3z/jiTfP+ABwTYdS854EECI7GjFOObld0UCAwEAAQ==`;
            const pubKeyDer = Buffer.from(validPubKeyInPEM, 'base64');
            expect(pubKeyDer.toString('hex')).to.equal('305c300d06092a864886f70d0101010500034b003048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450203010001');

            const key = new NodeRSA(null);
            key.importKey(pubKeyDer, 'pkcs8-public-der');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer);
            const pubKeyDerRet = await rootResolver.rsaPubKey(tokenId("a"));
            expect(pubKeyDerRet.slice(2)).to.equal(pubKeyDer.toString("hex"));
        });

        it('invalid sequence length', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e5774', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('data must be a node Buffer');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: wrong length")
        });

        it('invalid sequence type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b004048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450203010001', 'hex');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type SEQUENCE STRING")
        });

        it('invalid modulus type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048034100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450203010001', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('Expected 0x2: got 0x3');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type INTEGER")
        });

        it('invalid publicExponent type', async function () {
            const { rootResolver, registrar, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450903010001', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('Expected 0x2: got 0x9');

            await registrar.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootResolver.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type INTEGER")
        });
    });
});

function tokenId(domain) {
    return BigNumber.from(keccak256(toUtf8Bytes(domain)));
}