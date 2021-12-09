const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("Upgradeability", function() {
  let admin, addrs;
  beforeEach(async () => {
    const [admin, ...addrs] = await ethers.getSigners();
    
    const Token = await ethers.getContractFactory("Arcade");
    const arcade = await Token.deploy("10000000000000000000000");
    await arcade.deployed();

    const BEP20Price = await ethers.getContractFactory("MockBEP20Price");
    const bep20Price = await BEP20Price.deploy();
    await bep20Price.deployed();

    const Swap = await ethers.getContractFactory("ArcadeSwapV1");
    this.swap = await upgrades.deployProxy(
      Swap,
        [
          arcade.address, bep20Price.address
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