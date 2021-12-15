const { ethers, network, run, upgrades } = require("hardhat");
const { NomicLabsHardhatPluginError } = require("hardhat/plugins");
const manifestInMainnet = require("../.openzeppelin/unknown-56.json");
const manifestInTestnet = require("../.openzeppelin/unknown-97.json");


let totalGas = 0;
const countTotalGas = async (tx) => {
  let res = tx;
  if (tx.deployTransaction) tx = tx.deployTransaction;
  if (tx.wait) res = await tx.wait();
  if (res.gasUsed) totalGas += parseInt(res.gasUsed);
  else console.log("no gas data", { res, tx });
};

async function main() {
  const signers = await ethers.getSigners();
  // Find deployer signer in signers.
  let deployer;
  signers.forEach((a) => {
    if (a.address === process.env.ADDRESS) {
      deployer = a;
    }
  });
  if (!deployer) {
    throw new Error(`${process.env.ADDRESS} not found in signers!`);
  }

  console.log("Deploying contracts with the account:", deployer.address);
  console.log("Network:", network.name);

  if (network.name === "testnet" || network.name === "mainnet") {
    console.log("-------Upgrading-----------")
    const arcadeSwapV1 =
      network.name === "testnet"
        ? manifestInTestnet.proxies[0].address
        : manifestInMainnet.proxies[0].address;

    console.log("ArcadeSwapV1", arcadeSwapV1);

    // We get the contract to deploy
    const ArcadeSwapV2 = await ethers.getContractFactory(
      "ArcadeSwapV2"
    );
    const swapUpgrades = await upgrades.upgradeProxy(
      arcadeSwapV1,
      ArcadeSwapV2
    );
    await swapUpgrades.deployed();
    await swapUpgrades.upgradeToV2();

    await countTotalGas(swapUpgrades);
    console.log("Deployed ArcadeSwapV2 contracts", { totalGas });
    console.log("ArcadeSwapV2 deployed to:", swapUpgrades.address);
    
    console.log("-------Verifying-----------");

    let swapImpl
    try {
      // Verify
      swapImpl = await upgrades.erc1967.getImplementationAddress(
        swapUpgrades.address
      );
      console.log("Verifying swap contract address: ", swapImpl);
      await run("verify:verify", {
        address: swapImpl
      });
      
    } catch (error) {
      if (error instanceof NomicLabsHardhatPluginError) {
        console.log("Contract source code already verified");
      } else {
        console.error(error);
      }
    }
    console.log("-------Verified-----------");

    const deployerLog = { Label: "Deploying Address", Info: deployer.address };
    const proxyLog = {
      Label: "Deployed SwapV2 Proxy Address",
      Info: swapUpgrades.address,
    };
    const implementationLog = {
      Label: "Deployed Implementation Address",
      Info: swapImpl,
    };

    console.table([deployerLog, proxyLog, implementationLog]);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
