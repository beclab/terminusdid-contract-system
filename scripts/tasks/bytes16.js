const {ethers} = require("hardhat");

let l = ethers.utils.formatBytes32String("test")
console.log(l.substring(0,34))