const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { getContractFactory } = ethers;

describe('DomainUtils test', function() {
    
    async function deployTokenFixture() {

        const DomainUtils = await getContractFactory('DomainUtilsTest');
        const domainUtils = await DomainUtils.deploy();
        await domainUtils.deployed();

        return { domainUtils };
    }

    it('tokenId', async function() {
        const { domainUtils } = await loadFixture(deployTokenFixture);
        
        let testDomain = 'testDomain'
        let testTokenId = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(testDomain)) 
        
        let tokenId = await domainUtils.tokenId(testDomain)

        expect(tokenId.toHexString()).to.equal(testTokenId);

    })

    it('traceLevels', async function () {
        const { domainUtils } = await loadFixture(deployTokenFixture);

        let testDomain = 'testDomain.a.b.c'

        let length = await domainUtils.traceLevels(testDomain, 0)

        expect(length).to.equal(4);
    })

})
