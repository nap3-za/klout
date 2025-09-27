require("@nomicfoundation/hardhat-toolbox");
import('hardhat/config.js').HardhatUserConfig

module.exports = {
  solidity: "0.8.28",
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts"
  }
};