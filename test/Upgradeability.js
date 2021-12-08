const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Upgradeability", function() {
  let admin, addrs;
  beforeEach(async () => {
    const [admin, ...addrs] = await ethers.getSigners();
    const tempAddress = admin.address;

    const Swap = await ethers.getContractFactory("ArcadeSwapV1");
    this.swap = await upgrades.deployProxy(
      Swap,
        [
          tempAddress, tempAddress, tempAddress, tempAddress
        ],
        {
          kind: "uups",
          initializer: "__ArcadeSwap_init",
        }
      );
    await this.swap.deployed();
  });

  it("Should upgrade to V2.", async () => {
    // Check V2
    expect(await this.swap.version()).to.equal(1);

    const SwapV2 = await ethers.getContractFactory(
      "ArcadeSwapV2",
      admin
    );
  
    const swapV2 = await upgrades.upgradeProxy(
      this.swap.address,
      SwapV2
    );
    swapV2.upgradeToV2();

    expect(await swapV2.version()).to.equal(2);
  });
});