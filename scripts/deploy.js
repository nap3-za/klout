const hre = require("hardhat");

async function main() {
  // deploy my token
  const Token = await hre.ethers.getContractFactory("NAPE");
  const token = await Token.deploy(1_000_000); // 1 million tokens, MILLIONAIRRREEE, RICH
  await token.waitForDeployment();
  const tokenAddress = await token.getAddress();
  console.log("NFX Token deployed to:", tokenAddress);

  // userprofiles
  const Profiles = await hre.ethers.getContractFactory("UserProfiles");
  const profiles = await Profiles.deploy();
  await profiles.waitForDeployment();
  const profilesAddress = await profiles.getAddress();
  console.log("UserProfiles deployed to:", profilesAddress);

  // wagermanager with NFX token + userprofiles
  const WagerManager = await hre.ethers.getContractFactory("WagerManager");
  const wagers = await WagerManager.deploy(tokenAddress, profilesAddress);
  await wagers.waitForDeployment();
  const wagersAddress = await wagers.getAddress();
  console.log("WagerManager deployed to:", wagersAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
