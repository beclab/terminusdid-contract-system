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
const _AUTH_ADDRESSES = 0x14;

describe('Auth address test', function () {
    async function deployTokenFixture() {
        const [deployer, ...signers] = await getSigners();
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

        return { rootResolver, registrar, terminusDIDProxy, operator, signers };
    }


    it('set auth address', async function () {
        const { rootResolver, registrar, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        const authAddr = signers[1];
        await registrar.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        // All properties on a domain are optional
        const domain = await getDomain(domainOwner, rootResolver.address);

        // The named list of all type definitions
        const types = getTypes();

        // The data to sign
        const value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        const sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);

        await rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner);

        const ret = await rootResolver.connect(operator).authenticationAddress(tokenId(value.domain));
        expect(ret.length).to.equal(1);
        expect(ret[0].algorithm).to.equal(value.algorithm);
        expect(ret[0].addr).to.equal(value.addr);
    });

    it('set mutiple auth addresses and remove test', async function () {
        const { rootResolver, registrar, terminusDIDProxy, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        await registrar.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        const domain = await getDomain(domainOwner, rootResolver.address);
        const types = getTypes();

        for (let i = 0; i < 5; i++) {
            const authAddr = signers[i];
            const value = {
                addr: authAddr.address,
                algorithm: SignatureAlogorithm.ECDSA,
                domain: "a",
                signAt: curTsInSeconds(),
                action: Action.Add
            };

            const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
            const sigFromAuthAddress = await authAddr._signTypedData(domain, types, value);

            await rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddress, sigFromDomainOwner);
        }

        let rets = await rootResolver.connect(operator).authenticationAddress(tokenId("a"));
        expect(rets.length).to.equal(5);
        for (let i = 0; i < 5; i++) {
            expect(rets[i].algorithm).to.equal(SignatureAlogorithm.ECDSA);
            expect(rets[i].addr).to.equal(signers[i].address);
        }

        // rmeove the address in array middle with index 2
        let removeAddr = signers[2];
        let removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootResolver.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner);

        rets = await rootResolver.connect(operator).authenticationAddress(tokenId("a"));
        expect(rets.length).to.equal(4);
        for (let i = 0; i < 4; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // rmeove the address in array start with index 0
        removeAddr = signers[0];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootResolver.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner);

        rets = await rootResolver.connect(operator).authenticationAddress(tokenId("a"));
        expect(rets.length).to.equal(3);
        for (let i = 0; i < 3; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // rmeove the address in array end with index 4
        removeAddr = signers[4];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootResolver.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner);

        rets = await rootResolver.connect(operator).authenticationAddress(tokenId("a"));
        expect(rets.length).to.equal(2);
        for (let i = 0; i < 2; i++) {
            expect(rets[i].addr).to.not.equal(removeAddr.address);
        }

        // index 0, 2, 4 was removed, only index 1 , 3 address left
        for (let i = 0; i < 2; i++) {
            expect(rets[i].addr === signers[1].address || rets[i].addr === signers[3].address).to.be.true;
        }

        // remove all addresses
        removeAddr = signers[1];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootResolver.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner);

        removeAddr = signers[3];
        removeValue = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        }
        removeSigFromDomainOwner = await domainOwner._signTypedData(domain, types, removeValue);
        await rootResolver.connect(operator).removeAuthenticationAddress(removeValue, removeSigFromDomainOwner);

        let ret = await terminusDIDProxy.getTagValue(tokenId("a"), _AUTH_ADDRESSES);
        expect(ret.exists).to.be.false;

        rets = await rootResolver.connect(operator).authenticationAddress(tokenId("a"));
        expect(rets.length).to.equal(0);
    });

    it('tagGetter for key _AUTH_ADDRESSES', async function () {
        const { rootResolver } = await loadFixture(deployTokenFixture);
        const selector = await rootResolver.tagGetter(_AUTH_ADDRESSES);
        expect(selector).to.equal(id('authenticationAddress(uint256)').substring(0, 10));
    });

    it('error cases', async function () {
        const { rootResolver, registrar, operator, signers } = await loadFixture(deployTokenFixture);
        const domainOwner = signers[0];
        const authAddr = signers[1];
        await registrar.connect(operator).register(domainOwner.address, { domain: "a", did: "did", notes: "", allowSubdomain: true })

        const domain = await getDomain(domainOwner, rootResolver.address);
        const types = getTypes();

        let value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.Others,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        let sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        let sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);

        // cannot catch UnsupportedSigAlgorithm error as it will fail at function signature check, the algorithm can only be 0 in contract.
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.reverted;

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
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "SignatureIsValidOnlyInOneHour");

        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds() + 60*60*24,
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "SignatureIsValidOnlyInOneHour");

        // Unauthorized
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        const notOWner = signers[2];
        sigFromDomainOwner = await notOWner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "Unauthorized");

        // InvalidAddressSignature
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        const notAuthAddress = signers[3];
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await notAuthAddress._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "InvalidAddressSignature");

        // invalid signature length
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr + "abcd", sigFromDomainOwner)).to.be.revertedWith("invalid signature length");

        // AuthAddressNotExists
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        };
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootResolver.removeAuthenticationAddress(value, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "AuthAddressNotExists");

        // AddressNotFound
        for (let i = 4; i < 10; i++) {
            const authAddr = signers[i];
            const value = {
                addr: authAddr.address,
                algorithm: SignatureAlogorithm.ECDSA,
                domain: "a",
                signAt: curTsInSeconds(),
                action: Action.Add
            };

            const sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
            const sigFromAuthAddress = await authAddr._signTypedData(domain, types, value);

            await rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddress, sigFromDomainOwner);
        }
        const removeAddr = signers[10];
        value = {
            addr: removeAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        };
        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootResolver.removeAuthenticationAddress(value, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "AddressNotFound");

        // AuthAddressAlreadyExists
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "AuthAddressAlreadyExists");

        // Invalid action
        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Remove
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        sigFromAuthAddr = await authAddr._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).addAuthenticationAddress(value, sigFromAuthAddr, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "InvalidAction");

        value = {
            addr: authAddr.address,
            algorithm: SignatureAlogorithm.ECDSA,
            domain: "a",
            signAt: curTsInSeconds(),
            action: Action.Add
        };

        sigFromDomainOwner = await domainOwner._signTypedData(domain, types, value);
        await expect(rootResolver.connect(operator).removeAuthenticationAddress(value, sigFromDomainOwner)).to.be.revertedWithCustomError(rootResolver, "InvalidAction");
    });
});

function tokenId(domain) {
    return BigNumber.from(id(domain));
}

function curTsInSeconds() {
    return Math.floor(Date.now() / 1000);
}

async function getDomain(signer, contractAddr) {
    const chainId = await signer.getChainId();
    return {
        name: 'DID',
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