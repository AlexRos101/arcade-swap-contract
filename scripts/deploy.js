// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `npx hardhat run <script>` you"ll find the Hardhat
// Runtime Environment"s members available in the global scope.
const { ethers, network, run, upgrades } = require("hardhat");
const { NomicLabsHardhatPluginError } = require("hardhat/plugins");

const addresses = {
  mainnet: {
    factory: "0xb7926c0430afb07aa7defde6da862ae0bde767bc",
    arcade: "0xEA071968Faf66BE3cc424102fE9DE2F63BBCD12D",
    wbnb: "0xae13d989dac2f0debff460ac112a837c89baa7cd",
    busd: "0x8301f2213c0eed49a7e28ae4c3e91722919b8b47"
  },
  testnet: {
    factory: "0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73",
    arcade: "0xfF6269A074Af20D42571407E8E0E6648134F8878",
    wbnb: "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
    busd: "0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56"
  }
}

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
    console.log("-------Deploying-----------")
    const BEP20Price = await ethers.getContractFactory("BEP20Price");
    const bep20Price = await BEP20Price.deploy();
    await bep20Price.deployed();
    bep20Price.initialize(
      addresses[network.name].factory,
      addresses[network.name].wbnb,
      addresses[network.name].busd,
    );
    console.log("Deployed BEP20Price Address: " + bep20Price.address);

    const Swap = await ethers.getContractFactory("ArcadeSwapV1");
    const swapUpgrades = await upgrades.deployProxy(
      Swap,
      [
        addresses[network.name].arcade,
        bep20Price.address
      ],
      {
        kind: "uups",
        initializer: "__ArcadeSwap_init",
      }
    );
    await swapUpgrades.deployed();
    
    console.log("Deployed Swap Address: " + swapUpgrades.address);

    console.log("-------Verifying-----------");
    try {
      // verify
      await run("verify:verify", {
        address: bep20Price.address
      });

    } catch (error) {
      if (error instanceof NomicLabsHardhatPluginError) {
        console.log("Contract source code already verified");
      } else {
        console.error(error);
      }
    }

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
    const bep20PriceLog = {
      Label: "Deployed BEP20Price Address",
      Info: bep20Price.address,
    };
    const proxyLog = {
      Label: "Deployed Swap Proxy Address",
      Info: swapUpgrades.address,
    };
    const implementationLog = {
      Label: "Deployed Implementation Address",
      Info: swapImpl,
    };

    console.table([deployerLog, bep20PriceLog, proxyLog, implementationLog]);
  }
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
