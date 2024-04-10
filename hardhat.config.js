require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-preprocessor");
require("dotenv").config();
const fs = require("fs")

const PRIVATE_KEY = process.env.PRIVATE_KEY;
const REVIEWER_PRIVATE_KEY = process.env.REVIEWER_PRIVATE_KEY;
const OP_API_KEY = process.env.OP_API_KEY;

function getRemappings() {
    return fs
        .readFileSync("remappings.txt", "utf8")
        .split("\n")
        .filter(Boolean)
        .map((line) => line.trim().split("="));
}

module.exports = {
    solidity: {
        compilers: [
            {
                version: "0.8.21",
                settings: {
                    optimizer: {
                        enabled: true,
                        runs: 200,
                    },
                    viaIR: true,
                },
            }
        ],
    },
    networks: {
        hardhat: {
            allowUnlimitedContractSize: true,
        },
        goerli: {
            url: `https://ethereum-goerli.publicnode.com`,
            gas: 15000000,
            accounts: [PRIVATE_KEY]
        },
        op_sepolia: {
            url: `https://sepolia.optimism.io`,
            gas: 15000000,
            accounts: [PRIVATE_KEY, REVIEWER_PRIVATE_KEY]
        },
        op: {
            url: `https://mainnet.optimism.io`,
            gas: 15000000,
            accounts: [PRIVATE_KEY]
        }
    },
    paths: {
        sources: "./src", // Use ./src rather than ./contracts as Hardhat expects
        cache: "./cache_hardhat", // Use a different cache for Hardhat than Foundry
    },
    // This fully resolves paths for imports in the ./lib directory for Hardhat
    preprocess: {
        eachLine: (hre) => ({
            transform: (line) => {
                if (line.match(/^\s*import /i)) {
                    getRemappings().forEach(([find, replace]) => {
                        if (line.match(find)) {
                            line = line.replace(find, replace);
                        }
                    });
                }
                return line;
            },
        }),
    },
    etherscan: {
        apiKey: {
            op_sepolia: OP_API_KEY
        },
        customChains: [
            {
                network: "op_sepolia",
                chainId: 11155420,
                urls: {
                    apiURL: "https://api-sepolia-optimistic.etherscan.io/api",
                    browserURL: "https://sepolia-optimistic.etherscan.io"
                }
            }
        ]
    },
    addresses: {
        op_sepolia: {
            rootTagger: "0xaA5bE49799b6A71Eda74d22D01F7A808aFf41b3f",
            terminusDIDProxy: "0xe2D7c3a9013960E04d4E9F5F9B63fff37eEd97A8",
            appStoreReputation: "0xD681657e88225366Def1ab8e7195D3b19314fD10",
        }
    }
};
