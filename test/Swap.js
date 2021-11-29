const { expect } = require('chai');
const { soliditySha3 } = require("web3-utils");

describe('Swap setting without owner', function () {
  it('Swap setting should be failed.', async function () {
    const [owner, addr1] = await ethers.getSigners();

    const tempAddress = addr1.address;

    const Swap = await ethers.getContractFactory('ArcadeSwap');

    const hardhatSwap = 
      await Swap.deploy(tempAddress, tempAddress, tempAddress, tempAddress);

    await expect(hardhatSwap.connect(addr1).setArcadeBackendKey('ABC'))
      .to.be.revertedWith("Ownable: caller is not the owner");
  });
});

describe('Deposit and Withdraw Arcade token on Swap contract', function () {
  beforeEach(async function () {
    const [owner, addr1] = await ethers.getSigners();

    const tempAddress = addr1.address;

    const Token = await ethers.getContractFactory("Arcade");

    this.hardhatToken = await Token.deploy('10000000000000000000000');

    const Swap = await ethers.getContractFactory('ArcadeSwap');

    this.hardhatSwap = 
      await Swap.deploy(tempAddress, tempAddress, tempAddress, tempAddress);

    await this.hardhatSwap.setArcadeTokenAddress(this.hardhatToken.address);
    await this.hardhatToken.transfer(
      this.hardhatSwap.address,
      '1000000000000000000000'
    );

    expect(
      await this.hardhatToken.balanceOf(this.hardhatSwap.address)
    ).to.equal('1000000000000000000000');

    await this.hardhatSwap.setArcadeTokenAddress(this.hardhatToken.address);
    await this.hardhatSwap.setArcadeBackendKey('ArcadeDogeBackend');
    await this.hardhatSwap.setGameBackendKey(1, 'GameBackend');
    await this.hardhatSwap.setGamePointPrice(1, 5);
  });

  it(
    'Withdraw token from Swap contract should be successed.',
    async function () {
      const [owner, addr1] = await ethers.getSigners();
      await this.hardhatSwap.transferTo(addr1.address, 50);

      expect(await this.hardhatToken.balanceOf(addr1.address)).to.equal(50);
    }
  );

  describe('Deposit and Withdraw game point', async function() {
    beforeEach(async function() {
      const [owner, addr1] = await ethers.getSigners();
  
      await this.hardhatToken.transfer(addr1.address, '10000000000000000000');
      expect(
        await this.hardhatToken.balanceOf(addr1.address)
      ).to.equal('10000000000000000000');
    })
    it(
      'Deposit and Withdraw game point should be failed with incorrect sign',
      async function() {
        const [owner, addr1] = await ethers.getSigners();

        await this.hardhatToken.connect(addr1).approve(
          this.hardhatSwap.address,
          '5000000000000000000'
        );
        await this.hardhatSwap.connect(addr1).buyGamePoint(
          1,
          '5000000000000000000'
        );
  
        expect(
          await this.hardhatToken.balanceOf(this.hardhatSwap.address)
        ).to.equal('1005000000000000000000');
  
        await expect(
          this.hardhatSwap.connect(addr1).sellGamePoint(
            1,
            10000,
            soliditySha3('signature')
          )
        ).to.be.revertedWith('Verification data is incorrect.');
      }
    );
  
    it(
      'Deposit and Withdraw game point should be successed with correct sign',
      async function() {
        const [owner, addr1] = await ethers.getSigners();

        await this.hardhatToken.connect(addr1).approve(
          this.hardhatSwap.address,
          '5000000000000000000'
        );
        await this.hardhatSwap.connect(addr1).buyGamePoint(
          1,
          '5000000000000000000'
        );
  
        expect(
          await this.hardhatToken.balanceOf(this.hardhatSwap.address)
        ).to.equal('1005000000000000000000');
  
        await this.hardhatSwap.connect(addr1).sellGamePoint(
          1,
          10000,
          generateSignValue(
            1, 'GameBackend', 'ArcadeDogeBackend', addr1.address, 10000
          )
        )
  
        expect(
          await this.hardhatToken.balanceOf(this.hardhatSwap.address)
        ).to.equal('1000000000000000000000');
  
        expect(
          await this.hardhatToken.balanceOf(addr1.address)
        ).to.equal('10000000000000000000');
      }
    );

    it(
      'Deposit 2 times and Withdraw game point should be successed',
      async function() {
        const [owner, addr1] = await ethers.getSigners();
        
        await this.hardhatToken.connect(addr1).approve(
          this.hardhatSwap.address,
          '5000000000000000000'
        );
        await this.hardhatSwap.connect(addr1).buyGamePoint(
          1,
          '5000000000000000000'
        );

        await this.hardhatToken.connect(addr1).approve(
          this.hardhatSwap.address,
          '5000000000000000000'
        );
        await this.hardhatSwap.connect(addr1).buyGamePoint(
          1,
          '5000000000000000000'
        );
  
        expect(
          await this.hardhatToken.balanceOf(this.hardhatSwap.address)
        ).to.equal('1010000000000000000000');
  
        await this.hardhatSwap.connect(addr1).sellGamePoint(
          1,
          20000,
          generateSignValue(
            1, 'GameBackend', 'ArcadeDogeBackend', addr1.address, 20000
          )
        )
  
        expect(
          await this.hardhatToken.balanceOf(this.hardhatSwap.address)
        ).to.equal('1000000000000000000000');
  
        expect(
          await this.hardhatToken.balanceOf(addr1.address)
        ).to.equal('10000000000000000000');
      }
    );
  })
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