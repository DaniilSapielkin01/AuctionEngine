const { expect } = require("chai");
const { ethers } = require("hardhat");
const {
  isCallTrace,
} = require("hardhat/internal/hardhat-network/stack-traces/message-trace");

describe("AucEngine", function () {
  let owner;
  let seller;
  let buyer;
  let auct;

  beforeEach(async function () {
    const [owner, seller, buyer] = await ethers.getSigners();

    const AucEngine = await ethers.getContractFactory("AucEngine", owner);
    const auct = await AucEngine.deploy();
    await auct.deployed();
  });

  it("sets owner", async function () {
    const currentOwner = await auct.owner();
    console.log(currentOwner);
    expect(currentOwner).to.eq(owner.address);
  });

  async function getTimeStamp(blockNumber) {
    return (await ethers.provider.getBlock(blockNumber)).timestamp;
  }

  describe("AucEngine", function () {
    it("creates auction correctly", async function () {
      const duration = 60;

      const tx = await auct.createAuction(
        ethers.utils.parseEthers("0.0001"),
        3,
        "fake item",
        duration
      );

      const cAuction = await auct.auctions(0);
      console.log(cAuction);
      expect(cAuction.item).to.eq("fake item");
      expect(cAuction.discountRate).to.eq(3);

      console.log(tx);
      const ts = await getTimeStamp(tx.blockNumber);

      expect(cAuction.endsAt).to.eq(ts + duration);
    });
  });

  function delay(ms) {
    return new Promise((resolve) => setTimeout(resolve, ms));
  }

  describe("buy", function () {
    it("allows to buy", async function () {
      const duration = 60;
      await auct
        .connect(seller)
        .createAuction(
          ethers.utils.parseEthers("0.0001"),
          3,
          "fake item",
          duration
        );

      this.timeout(5000); // 5s

      await delay(1000);

      const buyTx = await auct
        .connect(buyer)
        .buy(0, { value: ethers.utils.parseEthers("0.0001") });

      const cAuction = await auct.auctions(0);
      const finalPrice = cAuction.finalPrice;

      await expect(() => buyTx).toChangeEtherBalance(
        seller,
        finalPrice - Math.floor((finalPrice * 10) / 100)
      );

      // ethereum-waffel
      await expect(buyTx)
        .to.emit(auct, "AuctionEnded")
        .withArgs(0, finalPrice, buyer.address);

      // check error
      await expect(
        auct
          .connect(buyer)
          .buy(0, { value: ethers.utils.parseEthers("0.0001") })
      ).to.be.revertedWith("stopped!"); // 74 string in contract
    });
  });
});
