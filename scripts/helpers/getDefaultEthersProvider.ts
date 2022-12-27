import { ethers } from "ethers";
import { CHAINID } from "../../constants/constants";

require("dotenv").config();

export const TEST_URI = {
  [CHAINID.ETH_MAINNET]: "https://mainnet.infura.io/v3/e1ba1d6948e34be2841be9cf8cb9f1bd",
  [CHAINID.AVAX_MAINNET]: process.env.AVAX_URI,
  [CHAINID.AVAX_FUJI]: process.env.FUJI_URI,
  [CHAINID.BSC_MAINNET]: "https://evocative-light-pallet.bsc.quiknode.pro/2b0ea02ae60dda158a7af6cb85b1d2776094994c/",
  [CHAINID.BSC_TEST]: "https://data-seed-prebsc-1-s3.binance.org:8545",
};

export type Networks = "mainnet" | "kovan" | "bsc_test";

export const getDefaultProvider = (network: Networks = "kovan") => {
  let url =
    network === "mainnet"
      ? process.env.MAINNET_URI
      : process.env.INFURA_KOVAN_URI;

  if (network === "bsc_test") {
    url = "https://data-seed-prebsc-2-s1.binance.org:8545/";
  }

  const provider = new ethers.providers.JsonRpcProvider(url);

  return provider;
};

export const getDefaultSigner = (path: string, network: Networks = "kovan") => {
  const mnemonic =
    network === "mainnet"
      ? process.env.MAINNET_MNEMONIC
      : process.env.KOVAN_MNEMONIC;

  if (!mnemonic) {
    throw new Error("No mnemonic set");
  }
  const signer = ethers.Wallet.fromMnemonic(mnemonic, path);
  return signer;
};


export const getSigner = (network: Networks, provider : ethers.providers.JsonRpcProvider) => {
  // const mnemonic =
  //   network === "mainnet"
  //     ? process.env.MAINNET_MNEMONIC
  //     : process.env.KOVAN_MNEMONIC;

  // if (!mnemonic) {
  //   throw new Error("No mnemonic set");
  // }

  //const signer = ethers.Wallet.fromMnemonic(mnemonic, path);
 //const signer = new ethers.Wallet("4f80b6066373a75ef617ba9f37ba2c0e8e3fb2330e77a93cfbe92983a90341b1", provider); // owner
 // const signer = new ethers.Wallet("9b684a236aea44ed197cef2d8d7db5175b1b1a9f57043fbe51b5ff7e7e28b7f5", provider); // admin
  const signer = new ethers.Wallet("d5d98f1f566f308bb5cb09c0e3dab962ba1db0b743ec40e132f8ef43b35f54a5", provider); // keeper
  
  return signer;
};