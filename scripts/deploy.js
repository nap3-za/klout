const hre = require("hardhat");

async function main() {
  // deploy my token
  const Token = await hre.ethers.getContractFactory("NAPE");
  const token = await Token.deploy(1_000_000); // 1 million tokens, MILLIONAIRRREEE, RICH
  await token.deployed();
  console.log("NFX Token deployed to:", token.address);

  // userprofiles
  const Profiles = await hre.ethers.getContractFactory("UserProfiles");
  const profiles = await Profiles.deploy();
  await profiles.deployed();
  console.log("UserProfiles deployed to:", profiles.address);

  // wagermanager with NFX token + userprofiles
  const WagerManager = await hre.ethers.getContractFactory("WagerManager");
  const wagers = await WagerManager.deploy(token.address, profiles.address);
  await wagers.deployed();
  console.log("WagerManager deployed to:", wagers.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
