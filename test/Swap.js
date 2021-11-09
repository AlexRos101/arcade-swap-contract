const { expect } = require('chai');
const { ethers } = require('hardhat');
const keccak256 = require('keccak256');

describe('Swap setting without owner', function () {
  it('Swap setting should be failed.', async function () {
    const [owner, addr1] = await ethers.getSigners();

    const Swap = await ethers.getContractFactory('ArcadeDogeSwap');

    const hardhatSwap = await Swap.deploy();

    await hardhatSwap.connect(addr1).setArcadeDogeBackendKey('ABC');
  });
});

describe('Deposit and Withdraw ArcadeDoge token on Swap contract', function() {
  it('Should be successed', async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('ArcadeDoge');
    const hardhatToken = await Token.deploy('1000000000000000000000');

    const Swap = await ethers.getContractFactory('ArcadeDogeSwap');
    const hardhatSwap = await Swap.deploy();
    
    await hardhatSwap.setArcadeDogeTokenAddress(hardhatToken.address);

    // Deposit 50 ArcadeDoge token to swap contract
    await hardhatToken.transfer(hardhatSwap.address, 50);
    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal(50);

    await hardhatSwap.transferTo(addr1.address, 50);
    expect(await hardhatToken.balanceOf(addr1.address)).to.equal(50);
  });
});

describe('Deposit and Withdraw game point on Swap contract with incorrect sign', function() {
  it('Should be failed', async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('ArcadeDoge');
    const hardhatToken = await Token.deploy('100000000000000000000000000000');

    const Swap = await ethers.getContractFactory('ArcadeDogeSwap');
    const hardhatSwap = await Swap.deploy();
    
    await hardhatSwap.setArcadeDogeTokenAddress(hardhatToken.address);
    await hardhatSwap.setArcadeDogeBackendKey('ArcadeDogeBackend');
    await hardhatSwap.setGameBackendKey(1, 'GameBackend');
    await hardhatSwap.setGamePointPrice(1, 5);

    // Deposit 50 ArcadeDoge token to swap contract
    await hardhatToken.transfer(hardhatSwap.address, '1000000000000000000000');
    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal('1000000000000000000000');

    await hardhatToken.transfer(addr1.address, '10000000000000000000');
    expect(await hardhatToken.balanceOf(addr1.address)).to.equal('10000000000000000000');

    await hardhatToken.connect(addr1).approve(hardhatSwap.address, '5000000000000000000');
    await hardhatSwap.connect(addr1).deposit(1, '5000000000000000000');

    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal('1005000000000000000000');

    await hardhatSwap.connect(addr1).withdraw(1, 10000, 'Signature');
  });
});

describe('Deposit and Withdraw game point on Swap contract with correct sign', function() {
  it('Should be successed', async function() {
    const [owner, addr1, addr2] = await ethers.getSigners();

    const Token = await ethers.getContractFactory('ArcadeDoge');
    const hardhatToken = await Token.deploy('100000000000000000000000000000');

    const Swap = await ethers.getContractFactory('ArcadeDogeSwap');
    const hardhatSwap = await Swap.deploy();
    
    await hardhatSwap.setArcadeDogeTokenAddress(hardhatToken.address);
    await hardhatSwap.setArcadeDogeBackendKey('ArcadeDogeBackend');
    await hardhatSwap.setGameBackendKey(1, 'GameBackend');
    await hardhatSwap.setGamePointPrice(1, 5);

    // Deposit 50 ArcadeDoge token to swap contract
    await hardhatToken.transfer(hardhatSwap.address, '1000000000000000000000');
    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal('1000000000000000000000');

    await hardhatToken.transfer(addr1.address, '10000000000000000000');
    expect(await hardhatToken.balanceOf(addr1.address)).to.equal('10000000000000000000');

    await hardhatToken.connect(addr1).approve(hardhatSwap.address, '5000000000000000000');
    await hardhatSwap.connect(addr1).deposit(1, '5000000000000000000');

    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal('1005000000000000000000');

    var sign = generateSignValue(1, 'GameBackend', 'ArcadeDogeBackend', addr1.address, 10000);

    await hardhatSwap.connect(addr1).withdraw(1, 10000, sign);

    expect(await hardhatToken.balanceOf(hardhatSwap.address)).to.equal('1000000000000000000000');

    expect(await hardhatToken.balanceOf(addr1.address)).to.equal('10000000000000000000');
  });
});

function generateSignValue(id, gameBackendKey, backendKey, address, amount) {
  var plainText = id + address.toLowerCase() + amount + gameBackendKey;
  var gameSign = keccak256(plainText).toString('hex');
  var backendSign = keccak256(Buffer.from(gameSign + backendKey)).toString('hex');
  return backendSign;
}