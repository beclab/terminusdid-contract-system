const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { getContractFactory } = ethers;

describe('DnsResolver test', function () {

    async function deployTokenFixture() {

        const DnsARecordResolver = await getContractFactory('DnsARecordResolver');
        const dnsARecordResolver = await DnsARecordResolver.deploy();
        await dnsARecordResolver.deployed();

        return { dnsARecordResolver };
    }

    function ipStringToUint8Array(ip) {
        const uint8 = new Uint8Array(4);
        ip.split('.').forEach( (num, index) => {
            num = Number(num);
            if (num > 255 | num < 0) {
                throw new Error('invalid ip address');
            }
            uint8[index] = num;
        })
        return uint8;
    }

    it('can parse dns a records bytes', async function () {
        const { dnsARecordResolver } = await loadFixture(deployTokenFixture);

        let ips = [
            '127.0.0.1',
            '8.8.8.8',
            '255.255.255.255',
            '123.123.123.123'
        ]

        for(let ip of ips) {
            let ipUint8 = ipStringToUint8Array(ip);
            let ipBufferStr = '0x' + Buffer.from(ipUint8).toString('hex');
            await dnsARecordResolver.parse(ipBufferStr);
        }
        
    });
});