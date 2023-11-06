const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers, upgrades } = require('hardhat');

const { getContractFactory, getSigners } = ethers;

describe('TerminusDID test', function () {
    let terminusDIDProxy;

    async function deployTokenFixture() {
        const [deployer] = await getSigners();
        let TerminusDID = await getContractFactory('TerminusDID');
        const name = "TestTerminusDID";
        const symbol = "TTDID";

        terminusDIDProxy = await upgrades.deployProxy(TerminusDID, [name, symbol], { initializer: 'initialize', kind: 'uups', constructorArgs: [], unsafeAllow: ['state-variable-immutable'] })
        await terminusDIDProxy.deployed();

        await terminusDIDProxy.setOperator(deployer.address);

        return { terminusDIDProxy, deployer };
    }

    describe('massive domain register test', function () {
        it('random domain label', async function () {
            const { terminusDIDProxy, deployer } = await loadFixture(deployTokenFixture);
            expect(await terminusDIDProxy.operator()).to.equal(deployer.address);

            const metadata = {
                did: "did",
                notes: "",
                allowSubdomain: true
            }
            let loop = 500;

            while (loop--) {
                let labelLength = loop % 500 || 1;
                const label = makeRandomLabel(labelLength);
                metadata.domain = label;
                const tx = await terminusDIDProxy.register(deployer.address, metadata);
                const receipt = await tx.wait();
                const tokenId = receipt.events[0].args.tokenId;

                const metadataRet = await terminusDIDProxy.getMetadata(tokenId);

                expect(metadataRet.domain).to.equal(label);
            }
        });
    })
});

function makeRandomLabel(length) {
    let result = '';
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789~`!@#$%^&*()_+-=?';
    const charactersLength = characters.length;
    let counter = 0;
    while (counter < length) {
        result += characters.charAt(Math.floor(Math.random() * charactersLength));
        counter += 1;
    }
    return result;
}