const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { utils, constants, getSigners, getContractFactory, provider, BigNumber } = ethers;
const { parseEther } = utils;
const { AddressZero } = constants;
const { getBalance } = provider;

describe('RsaResolver test', function () {

    async function deployTokenFixture() {

        const [deployer, owner, normalUser, validator1, ...addrs] = await getSigners();
        const Oracle = await getContractFactory('Oracle');
        const oracle = await Oracle.deploy();
        await oracle.deployed();
        
        const PublicResolver = await getContractFactory('PublicResolver');
        const publicResolver = await PublicResolver.deploy(oracle.address);
        await publicResolver.deployed();
        return { publicResolver, oracle };
    }

    describe('Basis test', function () {
        it('oracle check', async function () {
            const { publicResolver, oracle } = await loadFixture(deployTokenFixture);
            const oracleAddr = await publicResolver.oracle();
            expect(oracleAddr).to.equal(oracle.address);
        });
    })
});