const hre = require("hardhat");

async function main() {
  // userprofiles
  const Profiles = await hre.ethers.getContractFactory("UserProfiles");
  const profiles = await Profiles.deploy();
  await profiles.waitForDeployment();
  const profilesAddress = await profiles.getAddress();
  console.log("UserProfiles deployed to:", profilesAddress);

  // wagermanager without NFX token
  const WagerManager = await hre.ethers.getContractFactory("WagerManager");
  const wagers = await WagerManager.deploy(profilesAddress); // pass only profilesAddress now
  await wagers.waitForDeployment();
  const wagersAddress = await wagers.getAddress();
  console.log("WagerManager deployed to:", wagersAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
