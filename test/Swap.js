const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");
const { soliditySha3 } = require("web3-utils");

describe("Swap", function () {

  let owner, addr1;
  let swap, arcade;

  beforeEach(async function () {
    [owner, addr1] = await ethers.getSigners();

    const tempAddress = addr1.address;
    
    const Token = await ethers.getContractFactory("Arcade");
    arcade = await Token.deploy("10000000000000000000000");

    const Swap = await ethers.getContractFactory("ArcadeSwapV1");
    swap = await upgrades.deployProxy(
      Swap,
        [
          arcade.address, tempAddress, tempAddress, tempAddress
        ],
        {
          kind: "uups",
          initializer: "__ArcadeSwap_init",
        }
      );
    await swap.deployed();

    await arcade.transfer(
      swap.address,
      "1000000000000000000000"
    );

    expect(
      await arcade.balanceOf(swap.address)
    ).to.equal("1000000000000000000000");

    await swap.setArcadeBackendKey("ArcadeDogeBackend");
    await swap.setGameBackendKey(1, "GameBackend");
    await swap.setGamePointPrice(1, 5);
  });

  it("Swap setting should be failed.", async function () {
    await expect(swap.connect(addr1).setArcadeBackendKey("ABC"))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });

  it(
    "Withdraw token from Swap contract should be successed.",
    async function () {
      const [owner, addr1] = await ethers.getSigners();
      await swap.transferTo(addr1.address, 50);

      expect(await arcade.balanceOf(addr1.address)).to.equal(50);
    }
  );

  describe("Deposit and Withdraw game point", async () => {
    beforeEach(async () => {
      const [owner, addr1] = await ethers.getSigners();
  
      await arcade.transfer(addr1.address, "10000000000000000000");
      expect(
        await arcade.balanceOf(addr1.address)
      ).to.equal("10000000000000000000");
    })
    it(
      "Deposit and Withdraw game point should be failed with incorrect sign",
      async () => {
        const [owner, addr1] = await ethers.getSigners();

        await arcade.connect(addr1).approve(
          swap.address,
          "5000000000000000000"
        );
        await swap.connect(addr1).buyGamePoint(
          1,
          "5000000000000000000"
        );
  
        expect(
          await arcade.balanceOf(swap.address)
        ).to.equal("1005000000000000000000");
  
        await expect(
          swap.connect(addr1).sellGamePoint(
            1,
            10000,
            soliditySha3("signature")
          )
        ).to.be.revertedWith("Verification data is incorrect.");
      }
    );
  
    it(
      "Deposit and Withdraw game point should be successed with correct sign",
      async function() {
        const [owner, addr1] = await ethers.getSigners();

        await arcade.connect(addr1).approve(
          swap.address,
          "5000000000000000000"
        );
        await swap.connect(addr1).buyGamePoint(
          1,
          "5000000000000000000"
        );
  
        expect(
          await arcade.balanceOf(swap.address)
        ).to.equal("1005000000000000000000");
  
        await swap.connect(addr1).sellGamePoint(
          1,
          10000,
          generateSignValue(
            1, "GameBackend", "ArcadeDogeBackend", addr1.address, 10000
          )
        )
  
        expect(
          await arcade.balanceOf(swap.address)
        ).to.equal("1000000000000000000000");
  
        expect(
          await arcade.balanceOf(addr1.address)
        ).to.equal("10000000000000000000");
      }
    );

    it(
      "Deposit 2 times and Withdraw game point should be successed",
      async function() {
        const [owner, addr1] = await ethers.getSigners();
        
        await arcade.connect(addr1).approve(
          swap.address,
          "5000000000000000000"
        );
        await swap.connect(addr1).buyGamePoint(
          1,
          "5000000000000000000"
        );

        await arcade.connect(addr1).approve(
          swap.address,
          "5000000000000000000"
        );
        await swap.connect(addr1).buyGamePoint(
          1,
          "5000000000000000000"
        );
  
        expect(
          await arcade.balanceOf(swap.address)
        ).to.equal("1010000000000000000000");
  
        await swap.connect(addr1).sellGamePoint(
          1,
          20000,
          generateSignValue(
            1, "GameBackend", "ArcadeDogeBackend", addr1.address, 20000
          )
        )
  
        expect(
          await arcade.balanceOf(swap.address)
        ).to.equal("1000000000000000000000");
  
        expect(
          await arcade.balanceOf(addr1.address)
        ).to.equal("10000000000000000000");
      }
    );
  });
});

function generateSignValue(id, gameBackendKey, backendKey, address, amount) {
  const gameSign = soliditySha3(
    id,
    address.toLowerCase(),
    amount,
    soliditySha3(gameBackendKey)
  );
  const backendSign = soliditySha3(
    gameSign,
    soliditySha3(backendKey)
  );
  return backendSign;
}