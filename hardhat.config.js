require("@nomicfoundation/hardhat-toolbox");
require('@openzeppelin/hardhat-upgrades');
require("hardhat-preprocessor");
require("dotenv").config();
const fs = require("fs")

const ALCHEMY_API_KEY = process.env.ALCHEMY_API_KEY;
const PRIVATE_KEY = process.env.PRIVATE_KEY;

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
                },
            }
        ],
    },
    networks: {
        goerli: {
            url: `https://ethereum-goerli.publicnode.com`,
            gas: 15000000,
            accounts: [PRIVATE_KEY]
        },
        op_goerli: {
            url: `https://optimism-goerli.publicnode.com`,
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
    addresses: {
        rootResolver: "0x17e4C64d6417bc39393a8153853Bfa126347d0Cb",
    }
};
