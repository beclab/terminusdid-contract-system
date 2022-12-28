require("@nomiclabs/hardhat-etherscan");
require("@nomicfoundation/hardhat-toolbox");
require("@openzeppelin/hardhat-upgrades");
import { TEST_URI } from "./scripts/helpers/getDefaultEthersProvider";
import { BLOCK_NUMBER } from "./constants/constants";

require("dotenv").config();

const TEST_PRIVATEKEY = process.env.PRIVATE_KEY;
const TEST_MNEMONIC =
    "test test test test test test test test test test test junk";

const CHAINID = process.env.CHAINID ? Number(process.env.CHAINID) : 97;

export default {
  paths: {
    deploy: "scripts/deploy",
    deployments: "deployments",
  },
  solidity: {
    version: "0.8.16",
    settings: {
      optimizer: {
        runs: 200,
        enabled: true,
      },
    },
  },
  networks: {
    hardhat: {
      accounts: {
        mnemonic: TEST_MNEMONIC,
      },
      chainId: CHAINID,
      forking: {
        url: TEST_URI[CHAINID],
        blockNumber: BLOCK_NUMBER[CHAINID],
        gasLimit: 8e6,
      },
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/`,
      chainId: 4,
      accounts: [ `0x${TEST_PRIVATEKEY}` ],
    },
    goerli: {
      url: `https://rpc.ankr.com/eth_goerli`,
      chainId: 5,
      accounts: [ `0x${TEST_PRIVATEKEY}` ],
      gas: 10e6,
    },
    bsc_mainnet: {
      url: `https://bsc-dataseed1.binance.org/`,
      chainId: 56,
      accounts: [ `0x${TEST_PRIVATEKEY}` ],
      gas: 10e6,
    },
    bsc_testnet: {
      url: `https://data-seed-prebsc-1-s3.binance.org:8545/`,
      chainId: 97,
      accounts: [ `0x${TEST_PRIVATEKEY}` ],
      gas: 10e6,
    }
  },
  namedAccounts: {
    deployer: {
      default: 97,
      1: 0,
      42: 0,
      43114: 0,
      43113: 0,
      1313161554: 0,
      1313161555: 0,
      56: 0,
      97: '0x3f1f1f9f5e3CC97820f4bc04816E67eFf18a0299',
    },

  },
  mocha: {
    timeout: 500000,
  },
  etherscan: {
    apiKey: {
      goerli: process.env.ETHERSCAN_GOERLI_API_KEY
    }
  },
  gasReporter: {
    enabled: true,
  },
};

// task("export-deployments", "Exports deployments into JSON", exportDeployments);
// task("verify-contracts", "Verify solidity source", verifyContracts);


