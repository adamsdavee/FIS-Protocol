const { network } = require("hardhat");
require("dotenv").config();

module.exports = async ({ deployments, getNamedAccounts }) => {
  const { deployer } = await getNamedAccounts();
  const { deploy, log } = deployments;

  log("Deploying FIS........");
  const FISToken = await deploy("FISCOIN", {
    from: deployer,
    args: [],
    log: true,
  });
  log(`Contract deployed at ${FISToken.address}`);

  //   if (!(chainId == 31337) && process.env.ETHERSCAN_API_KEY) {
  //     await verify(fractionalAsset.address, []);
  //     log("verified........");
  //   }
};

module.exports.tags = ["all", "FIS"];
