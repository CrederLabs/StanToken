const {
    time,
    mine,
    loadFixture,
} = require("@nomicfoundation/hardhat-toolbox/network-helpers");
const { anyValue } = require("@nomicfoundation/hardhat-chai-matchers/withArgs");
const { expect } = require("chai");

describe("StanToken", function () {
    // We define a fixture to reuse the same setup in every test.
    // We use loadFixture to run this setup once, snapshot that state,
    // and reset Hardhat Network to that snapshot in every test.
    async function deployFixture() {
        // Contracts are deployed using the first signer/account by default
        const [owner, otherAccount, userA, userB, userC, signer2, signer3] = await ethers.getSigners();

        const StanToken = await ethers.getContractFactory("StanToken");
        const stanToken = await StanToken.deploy();

        return { stanToken, owner, otherAccount, userA, userB, userC, signer2, signer3 };
    }

    describe("Deployment", function () {
        it("Should set the signer", async function () {
            const { stanToken, owner } = await loadFixture(deployFixture);

            expect(await stanToken.isSigner(owner.address)).to.equal(true);
        });
    });

    describe("Blacklist", function () {
        it("Should freeze an address", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await stanToken.freeze(otherAccount.address);
            expect(await stanToken.isFrozen(otherAccount.address)).to.equal(true);
        });

        it("Should unfreeze an address", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await stanToken.freeze(otherAccount.address);
            await stanToken.unfreeze(otherAccount.address);
            expect(await stanToken.isFrozen(otherAccount.address)).to.equal(false);
        });

        it("Should revert if an address is frozen by a non-owner", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await expect(stanToken.connect(otherAccount).freeze(owner.address)).to.be.reverted;
        });

        it("Should revert if an address is unfrozen by a non-owner", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await stanToken.freeze(owner.address);
            await expect(stanToken.connect(otherAccount).unfreeze(owner.address)).to.be.reverted;
        });
        
        it("Should revert if frozen address tries to transfer", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await stanToken.freeze(otherAccount.address);
            await expect(stanToken.connect(otherAccount).transfer(owner.address, 1)).to.be.reverted;
        });

        it("Should revert if frozen address tries to transferFrom", async function () {
            const { stanToken, owner, otherAccount } = await loadFixture(deployFixture);

            await stanToken.freeze(otherAccount.address);
            await expect(stanToken.connect(otherAccount).transferFrom(owner.address, otherAccount.address, 1)).to.be.reverted;
        });
    });

    describe("Vesting", function () {
        it("Should release the tokens for the user", async function () {
            const { stanToken, owner, userA } = await loadFixture(deployFixture);

            // approve
            await stanToken.approve(owner.address, "10000000000000000000000");

            let timestamp = await time.latest();

            for (let i = 0; i < 10; i++) {
                await stanToken.lock(userA.address, "100000000000000000000", timestamp + 600 * (i + 1));
            }

            await stanToken.release(userA.address);
            expect(await stanToken.lockCount(userA.address)).to.equal(10);

            for (let i = 0; i < 10; i++) {
                await stanToken.lockState(userA.address, i);
            }

            await time.increase(600 * 6 + 60);

            await stanToken.release(userA.address);

            expect(await stanToken.releasedHistoryCount(userA.address)).to.equal(6);
        });

        // Lock 1000 STAN for userA, 2000 STAN for userB, and 3000, 4000 STAN for userC.
        // After 6 months, release 1000 STAN for userA.
        // After 12 months, release 2000 STAN for userB.
        // After 18 months, release 3000 STAN for userC.
        // After 24 months, release 4000 STAN for userC.
        it("Should release the locked tokens for the users", async function () {
            const { stanToken, owner, userA, userB, userC } = await loadFixture(deployFixture);

            stanToken.approve(owner.address, "10000000000000000000000");

            let currentTimestamp = await time.latest();

            await stanToken.lock(userA.address, "1000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 6);
            await stanToken.lockAfter(userB.address, "2000000000000000000000", 60 * 60 * 24 * 30 * 12);
            await stanToken.lock(userC.address, "3000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 18);
            await stanToken.lockAfter(userC.address, "4000000000000000000000", 60 * 60 * 24 * 30 * 24);
            
            await time.increase(60 * 60 * 24 * 30 * 6);
            await stanToken.release(userA.address);

            await time.increase(60 * 60 * 24 * 30 * 12);
            await stanToken.release(userB.address);

            await time.increase(60 * 60 * 24 * 30 * 18);
            await stanToken.release(userC.address);

            expect(await stanToken.balanceOf(userC.address)).to.equal("7000000000000000000000");

            // stanToken Contract balanceOf
            expect(await stanToken.balanceOf(stanToken.target)).to.equal(0);
        });

        // cancelLock test
        it("Should cancel the locked tokens for the users", async function () {
            const { stanToken, owner, userA, userB, userC } = await loadFixture(deployFixture);

            stanToken.approve(owner.address, "10000000000000000000000");

            let currentTimestamp = await time.latest();

            await stanToken.lock(userA.address, "1000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 6);
            await stanToken.lock(userB.address, "2000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 12);
            await stanToken.lock(userC.address, "3000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 18);
            await stanToken.lock(userC.address, "4000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 24);

            await time.increase(60 * 60 * 24 * 30 * 3);
            await stanToken.cancelLock(userA.address, 0, owner.address);
            await stanToken.cancelLock(userB.address, 0, owner.address);
            await stanToken.cancelLock(userC.address, 0, owner.address);

            await time.increase(60 * 60 * 24 * 30 * 3);

            await expect(stanToken.release(userA.address)).to.be.revertedWith("No claimable tokens.");
            await expect(stanToken.release(userB.address)).to.be.revertedWith("No claimable tokens.");

            await stanToken.release(userC.address);

            expect(await stanToken.balanceOf(userC.address)).to.equal("0");

            // After 18 months (total of 24 months)
            await time.increase(60 * 60 * 24 * 30 * 18);

            // userC release
            await stanToken.release(userC.address);

            expect(await stanToken.balanceOf(userC.address)).to.equal("4000000000000000000000");
        });
    });

    describe("multisig", function () {
        it("Should lock tokens for the users' with confirmSignature", async function () {
            const { stanToken, owner, userA, signer2, signer3 } = await loadFixture(deployFixture);

            // When attempting to add a signer that has already been added
            await expect(stanToken.addSigner(owner.address)).to.revertedWith("Already added");

            // Adding two signers (this will require confirmation from at least two signers to execute the function).
            await stanToken.addSigner(signer2.address);
            await stanToken.addSigner(signer3.address);

            await stanToken.approve(owner.address, "100000000000000000000");

            expect(await stanToken.lockCount(userA.address)).to.equal(0);

            let timestamp = await time.latest();
            await stanToken.lock(userA.address, "100000000000000000000", timestamp + 600 * 1);

            // Lock quantity check: Not yet executed as it has not reached the majority.
            expect(await stanToken.lockCount(userA.address)).to.equal(0);

            await stanToken.connect(signer2).lock(userA.address, "100000000000000000000", timestamp + 600 * 1);

            // Executed as it has exceeded the majority.
            expect(await stanToken.lockCount(userA.address)).to.equal(1);

            await time.increase(600 * 6 + 60);

            expect(await stanToken.balanceOf(userA.address)).to.equal("0");

            await stanToken.release(userA.address);

            expect(await stanToken.balanceOf(userA.address)).to.equal("100000000000000000000");
        });

        it("Should remove signers", async function () {
            const { stanToken, owner, userA, signer2, signer3 } = await loadFixture(deployFixture);

            await stanToken.addSigner(signer2.address);
            await stanToken.addSigner(signer3.address);

            expect(await stanToken.signersLength()).to.equal(3);

            await stanToken.removeSigner(signer2.address);
            expect(await stanToken.signersLength()).to.equal(3);
            await stanToken.connect(signer2).removeSigner(signer2.address);

            expect(await stanToken.signersLength()).to.equal(2);
        });

        // Check if the `nonce` increments when the block number exceeds 100,000.
        it("Should increase nonce by increasing block number", async function () {
            const { stanToken } = await loadFixture(deployFixture);

            expect(await stanToken.currentNonce()).to.equal(0);

            await mine(100000);

            expect(await stanToken.currentNonce()).to.equal(1);
        });
    });
});
  