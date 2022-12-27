const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { getContractFactory, utils } = ethers;

describe('DnsARecordResolver test', function () {

    async function deployTokenFixture() {

        const DnsARecordResolver = await getContractFactory('DnsARecordResolver');
        const dnsARecordResolver = await DnsARecordResolver.deploy();
        await dnsARecordResolver.deployed();

        return { dnsARecordResolver };
    }

    it('can parse dns a records bytes', async function () {
        const { dnsARecordResolver } = await loadFixture(deployTokenFixture);

        let ips = [
            [127, 0, 0, 1],
            [8, 8, 8, 8],
            [255, 255, 255, 255],
            [123, 123, 123, 123]
        ]

        for (let ip of ips) {
            let ipBuffer = '0x' + Buffer.from(ip).toString('hex');
            const isValid = await dnsARecordResolver.dnsARecordResolverValidate(ipBuffer);
            expect(isValid).equal(0);

            const [status, ipBytes] = await dnsARecordResolver.dnsARecordResolverParse(ipBuffer);
            expect(status).equal(0);

            const abiDecoder = new utils.AbiCoder();
            const ipRet = abiDecoder.decode(["uint8[]"], ipBytes);
            // deep equality
            expect(ipRet[0]).to.eql(ip);
        }
    });

    it('invalid ip format', async function () {
        const { dnsARecordResolver } = await loadFixture(deployTokenFixture);

        let ipBuffers = [
            "0xffffff",
            "0xffffffffff",
            "0x1fffffffff",
            "0x0000000001",
        ]

        for (let ipBuffer of ipBuffers) {
            const isValid = await dnsARecordResolver.dnsARecordResolverValidate(ipBuffer);
            expect(isValid).equal(4);

            const [status, ipBytes] = await dnsARecordResolver.dnsARecordResolverParse(ipBuffer);
            expect(status).equal(4);
            expect(ipBytes).equal("0x");
        }
    });
});