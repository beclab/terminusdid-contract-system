const { loadFixture } = require('@nomicfoundation/hardhat-network-helpers');
const { expect } = require('chai');
const { ethers } = require('hardhat');

const { BigNumber, utils, constants, getContractFactory, getSigners } = ethers;
const { AddressZero } = constants;
const { id } = utils;

const SignatureAlogorithm = {
    ECDSA: 0,
    Others: 1,
};
const Action = {
    Add: 0,
    Remove: 1,
}

describe('Auth address test', function () {
    async function deployTokenFixture() {
        const [deployer, ...signers] = await getSigners();
        const operator = deployer;

        let ABI = await getContractFactory('src/utils/external/ABI.sol:ABI');
        let abiLib = await ABI.deploy();

        let TerminusDID = await getContractFactory('TerminusDID', {
            libraries: {
                ABI: abiLib.address,
              },
        });
        const name = "TerminusDID";
        const symbol = "TDID";

        let terminusDIDProxy = await upgrades.deployProxy(TerminusDID, [name, symbol], { 
            initializer: 'initialize',
            kind: 'uups', 
            constructorArgs: [], 
            unsafeAllow: ['state-variable-immutable', 'external-library-linking'] 
        })
        await terminusDIDProxy.deployed();

        await terminusDIDProxy.setOperator(operator.address);

        const RootTagger = await getContractFactory('RootTagger');
        const rootTagger = await RootTagger.deploy(terminusDIDProxy.address, operator.address);
        await rootTagger.deployed();

        const authAddressesTagName = "authAddresses";
        // AuthAddress[] type bytes: 0x04060002010107
        const authAddressesType = utils.arrayify("0x04060002010107");
        const rootDomain = "";
        const fieldNames = new Array();
        fieldNames.push(["algorithm", "addr"]);
        await terminusDIDProxy.connect(operator).defineTag(rootDomain, authAddressesTagName, authAddressesType, fieldNames);
        await terminusDIDProxy.connect(operator).setTagger(rootDomain, authAddressesTagName, rootTagger.address);


        return { rootTagger, terminusDIDProxy, operator, signers };
    }


    it('set auth address', async function () {
        const { rootTagger, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        const authAddr = signers[1];
        await terminusDIDProxy.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        // All properties on a domain are optional
        const domain = await getDomain(domainOwner, rootTagger.address);

        // The named list of all type definitions
        const types = getTypes();

        // The data to sign
        const value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        const sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);

        await rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner);

        const ret = await rootTagger.connect(operator).getAuthenticationAddresses(value.domain);
        expect(ret.length).to.equal(1);
        expect(ret[0].algorithm).to.equal(value.algorithm);
        expect(ret[0].addr).to.equal(value.addr);
    });

    it('set mutiple auth addresses and remove test', async function () {
        const { rootTagger, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        await terminusDIDProxy.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        const domain = await getDomain(domainOwner, rootTagger.address);
        const types = getTypes();

        for (let i = 0; i < 5; i++) {
            const authAddr = signers[i];
            const value = {
                addr: authAddr.address,
                algorithm: SignatureAlogorithm.ECDSA,
                domain: "a",
                signAt: curTsInSeconds() - 30 * 60,
                action: Action.Add
            };

            const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
            const sigFromAuthAddress = await authAddr._signTypedData(domain, types, value);

            await rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddress, sigFromDomainOwner);
        }

        let rets = await rootTagger.getAuthenticationAddresses("a");
        expect(rets.length).to.equal(5);
        for (let i = 0; i < 5; i++) {
            expect(rets[i].algorithm).to.equal(SignatureAlogorithm.ECDSA);
            expect(rets[i].addr).to.equal(signers[i].address);
        }

        // rmeove the address in array middle with index 2
        // [[signers[0], signers[1], signers[2], signers[3], signers[4]] => [[signers[0], signers[1], signers[4], signers[3]]
        let removeAddr = signers[2];
        let removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootTagger.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner, 2);

        rets = await rootTagger.getAuthenticationAddresses("a");
        expect(rets.length).to.equal(4);
        for (let i = 0; i < 4; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // rmeove the address in array start with index 0
        // [[signers[0], signers[1], signers[4], signers[3]] => [[signers[3], signers[1], signers[4]]
        removeAddr = signers[0];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootTagger.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner, 0);

        rets = await rootTagger.getAuthenticationAddresses("a");
        expect(rets.length).to.equal(3);
        for (let i = 0; i < 3; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // remove the address in array end with index 4
        // [[signers[3], signers[1], signers[4]] => [[signers[3], signers[1]]
        removeAddr = signers[4];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootTagger.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner, 2);

        rets = await rootTagger.getAuthenticationAddresses("a");
        expect(rets.length).to.equal(2);
        for (let i = 0; i < 2; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // index 0, 2, 4 was removed, only index 1 , 3 address left
        for (let i = 0; i < 2; i++) {
            expect(rets[i].addr === signers[1].address || rets[i].addr === signers[3].address).to.be.true;
        }

        // remove all addresses
        // [[signers[3], signers[1]] -> [[signers[3]]
        removeAddr = signers[1];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootTagger.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner, 1);

        // [[signers[3]] -> null
        removeAddr = signers[3];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootTagger.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner, 0);

        const rootDomain = "";
        const authAddressesTagName = "authAddresses";
        let ret = await terminusDIDProxy.hasTag(rootDomain, "a", authAddressesTagName);
        expect(ret).to.be.false;

        await expect(rootTagger.connect(operator).getAuthenticationAddresses("a")).to.be.revertedWithCustomError(rootTagger, "RootTagNoExists");
    });

    it('error cases', async function () {
        const { rootTagger, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        const authAddr = signers[1];
        await terminusDIDProxy.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        const domain = await getDomain(domainOwner, rootTagger.address);
        const types = getTypes();

        let value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.Others,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        let sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        let sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);

        // cannot catch UnsupportedSigAlgorithm error as it will fail at function signature check, the algorithm can only be 0 in contract.
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.reverted;

        // signature expired
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: 0,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootTagger, "SignatureIsValidOnlyInOneHour");

        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() + 60*60*24,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootTagger, "SignatureIsValidOnlyInOneHour");

        // Unauthorized
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        const notOWner = signers[2];
        sigFromDomainOwner = await notOWner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootTagger, "Unauthorized");

        // InvalidAddressSignature
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        const notAuthAddress = signers[3];
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await notAuthAddress._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootTagger, "InvalidAddressSignature");

        // invalid signature length
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr + "abcd", sigFromDomainOwner)).to.be.revertedWith("invalid signature length");

        // RootTagNoExists
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        };
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootTagger.removeAuthenticationAddress(value, sigFromDomainOwner, 0)).to.be.revertedWithCustomError(rootTagger, "RootTagNoExists");

        // InvalidIndex
        for (let i = 4; i < 10; i++) {
            const authAddr = signers[i];
            const value = {
                addr: authAddr.address,
                algorithm: SignatureAlogorithm.ECDSA,
                domain: "a",
                signAt: curTsInSeconds() - 30 * 60,
                action: Action.Add
            };

            const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
            const sigFromAuthAddress = await authAddr._signTypedData(domain, types, value);

            await rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddress, sigFromDomainOwner);
        }
        const removeAddr = signers[10];
        value = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        };
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootTagger.removeAuthenticationAddress(value, sigFromDomainOwner, 6)).to.be.revertedWithCustomError(rootTagger, "InvalidIndex");

        const removeAddr1 = signers[0];
        value = {
            addr: removeAddr1.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        };
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootTagger.removeAuthenticationAddress(value, sigFromDomainOwner, 0)).to.be.revertedWithCustomError(rootTagger, "InvalidIndex");


        // can add duplicate address
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner);
        await rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner);
        const rets = await rootTagger.getAuthenticationAddresses("a");
        expect(rets.length).to.equal(8);
        expect(rets[6].addr).to.equal(rets[7].addr);

        // Invalid action
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Remove
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootTagger, "InvalidAction");

        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootTagger.connect(operator).removeAuthenticationAddress(value, sigFromDomainOwner, 0)).to.be.revertedWithCustomError(rootTagger, "InvalidAction");
    });

    it('use ECDSA lib to avoid ecrecover error for zero address', async function() {
        const { rootTagger, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        const authAddr = signers[1];
        await terminusDIDProxy.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        const domain = await getDomain(domainOwner, rootTagger.address);
        const types = getTypes();

        let value = {
            addr: AddressZero,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() - 30 * 60,
            action: Action.Add
        };

        let sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        let sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        let sigWrong = sigFromAuthAddr.substring(0, 130) + 'ff';

        await expect(rootTagger.connect(operator).addAuthenticationAddress(value, sigWrong, sigFromDomainOwner))
            .to.be.revertedWithCustomError(rootTagger, 'ECDSAInvalidSignature');
    })
});

function curTsInSeconds() {
    return Math.floor(Date.now() / 1000);
}

async function getDomain(signer, contractAddr) {
    const chainId = await signer.getChainId();
    return {
        name: 'Terminus DID Root Tagger',
        version: '1',
        chainId: chainId,
        verifyingContract: contractAddr
    };
}

function getTypes() {
    return {
        AuthAddressReq: [
            { name: 'addr', type: 'address' },
            { name: 'algorithm', type: 'uint8' },
            { name: 'domain', type: 'string' },
            { name: 'signAt', type: 'uint256' },
            { name: 'action', type: 'uint8' },
        ]
    };
}