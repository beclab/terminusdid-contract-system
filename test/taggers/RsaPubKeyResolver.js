const crypto = require('crypto');
const NodeRSA = require('node-rsa');
const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { utils, getContractFactory, getSigners } = ethers;

describe('RsaPubKey test', function () {
    async function deployTokenFixture() {
        const [deployer] = await getSigners();
        const operator = deployer;

        let TerminusDID = await getContractFactory('TerminusDID');
        const name = "TerminusDID";
        const symbol = "TDID";

        let terminusDIDProxy = await upgrades.deployProxy(TerminusDID, [name, symbol], { initializer: 'initialize', kind: 'uups', constructorArgs: [], unsafeAllow: ['state-variable-immutable'] })
        await terminusDIDProxy.deployed();

        await terminusDIDProxy.setOperator(operator.address);

        const RootTagger = await getContractFactory('RootTagger');
        const rootTagger = await RootTagger.deploy(terminusDIDProxy.address, operator.address);
        await rootTagger.deployed();

        const rsaPubKeyTagName = "rsaPubKey";
        // string type bytes: 0x09
        const rsaPubKeyType = utils.arrayify("0x09");
        const rootDomain = "";
        const fieldNames = new Array();
        await terminusDIDProxy.connect(operator).defineTag(rootDomain, rsaPubKeyTagName, rsaPubKeyType, fieldNames);
        await terminusDIDProxy.connect(operator).setTagger(rootDomain, rsaPubKeyTagName, rootTagger.address);

        return { rootTagger, terminusDIDProxy, operator };
    }

    async function canParseRsaPubKeyWithDifferentLength(length) {
        const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
        const { publicKey, _ } = crypto.generateKeyPairSync("rsa", {
            modulusLength: length,
        });
        const pubKeyDer = publicKey.export({ type: 'spki', format: 'der' });

        await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        // set and get pubKey from contract
        await rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer);
        const pubKeyDerRet = await rootTagger.getRsaPubKey("a");
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
            const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
            const validPubKeyInPEM = `MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAxnP0GxM51skm0/kd3cd1
            XNGt9Dhag73E2LSQ3qoxo7jDMOSRl1//w202tzLfPGparrOuH2gdPXmiwSkFlh8m
            kmT9JL/GFB3Y6361mvyYQOS4CwG8QaTMkJMAyLggW2pnwLoE8PP40d6A+yUzGbW5
            bPwh3XvrbmY8DucQ2dTxEFLu7mv6gv2xjB+yDsYaT/xgdr+eu+O3FarKUMjnYTyx
            TTZ8lyVRtC2GBJqex9s300XjsNGkpmGESt2w+i2OX8aTSbYXBNFa5mGM1wmbAO0q
            xmZP4f/ljpJTuLRGKxGmKJ56eUSrIkTTaBYesmsh0ONSiwnajnuC5Il5NR08kX+w
            vwIDAQAB`;
            const pubKeyDer = Buffer.from(validPubKeyInPEM, 'base64');
            expect(pubKeyDer.toString('hex')).to.equal('30820122300d06092a864886f70d01010105000382010f003082010a0282010100c673f41b1339d6c926d3f91dddc7755cd1adf4385a83bdc4d8b490deaa31a3b8c330e491975fffc36d36b732df3c6a5aaeb3ae1f681d3d79a2c12905961f269264fd24bfc6141dd8eb7eb59afc9840e4b80b01bc41a4cc909300c8b8205b6a67c0ba04f0f3f8d1de80fb253319b5b96cfc21dd7beb6e663c0ee710d9d4f11052eeee6bfa82fdb18c1fb20ec61a4ffc6076bf9ebbe3b715aaca50c8e7613cb14d367c972551b42d86049a9ec7db37d345e3b0d1a4a661844addb0fa2d8e5fc69349b61704d15ae6618cd7099b00ed2ac6664fe1ffe58e9253b8b4462b11a6289e7a7944ab2244d368161eb26b21d0e3528b09da8e7b82e48979351d3c917fb0bf0203010001');

            const key = new NodeRSA(null);
            key.importKey(pubKeyDer, 'pkcs8-public-der');

            await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer);
            const pubKeyDerRet = await rootTagger.getRsaPubKey("a");
            expect(pubKeyDerRet.slice(2)).to.equal(pubKeyDer.toString("hex"));
        });

        it('invalid sequence length', async function () {
            const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e5774', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('data must be a node Buffer');

            await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: wrong length")
        });

        it('invalid sequence type', async function () {
            const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b004048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450203010001', 'hex');

            await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type SEQUENCE STRING")
        });

        it('invalid modulus type', async function () {
            const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048034100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450203010001', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('Expected 0x2: got 0x3');

            await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type INTEGER")
        });

        it('invalid publicExponent type', async function () {
            const { rootTagger, terminusDIDProxy, operator } = await loadFixture(deployTokenFixture);
            const pubKeyDer = Buffer.from('305c300d06092a864886f70d0101010500034b003048024100c0ad28bdbcf08b992f3af1586943ed3791eefd199a5d833905cbdb01a826b26b6735eefdf4d9677cff8e24df3fe001c1361d4bce78104088ec68c538e6e577450903010001', 'hex');

            const key = new NodeRSA(null);
            expect(key.importKey.bind(key, pubKeyDer, 'pkcs8-public-der')).to.throw('Expected 0x2: got 0x9');

            await terminusDIDProxy.connect(operator).register(operator.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })
            await expect(rootTagger.connect(operator).setRsaPubKey("a", pubKeyDer)).to.be.revertedWith("Asn1Decode: not type INTEGER")
        });
    });
});