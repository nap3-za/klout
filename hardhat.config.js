require("@nomicfoundation/hardhat-toolbox");


module.exports = {
  solidity: "0.8.28",
  // defaultNetwork: "hardhat", // default network when running tasks/scripts
  networks: {
    hardhat: {
      chainId: 1337, // ensures MetaMask localhost matches
    },
    localhost: {
      url: "http://127.0.0.1:8545",
      chainId: 1337,
    },
  },
  paths: {
    sources: "./contracts",
    tests: "./test",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 20000, // 20 seconds per test, handy for async blockchain calls
  },
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY || "", // for verifying contracts on Etherscan
  },
};
