const {
    time,
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
        const [owner, otherAccount, userA, userB, userC] = await ethers.getSigners();

        const StanToken = await ethers.getContractFactory("StanToken");
        const stanToken = await StanToken.deploy();

        return { stanToken, owner, otherAccount, userA, userB, userC };
    }

    describe("Deployment", function () {
        it("Should set the right owner", async function () {
            const { stanToken, owner } = await loadFixture(deployFixture);

            expect(await stanToken.owner()).to.equal(owner.address);
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

    // Vesting tests
    describe("Vesting", function () {

        // userA 에게 1000 STAN, userB 에게 2000 STAN, userC 에게 3000, 4000 STAN을 lock
        it("Should lock the tokens for the users", async function () {
            const { stanToken, owner, userA, userB, userC } = await loadFixture(deployFixture);

            // approve
            stanToken.approve(owner.address, "10000000000000000000000");

            let timestamp = await time.latest() + 1000;

            await stanToken.lock(userA.address, "1000000000000000000000", timestamp);
            await stanToken.lock(userB.address, "2000000000000000000000", timestamp);
            await stanToken.lock(userC.address, "3000000000000000000000", timestamp);
            await stanToken.lock(userC.address, "4000000000000000000000", timestamp);

            // lockCount
            expect(await stanToken.lockCount(userA.address)).to.equal(1);
            expect(await stanToken.lockCount(userB.address)).to.equal(1);
            expect(await stanToken.lockCount(userC.address)).to.equal(2);

            // lockState
            expect(await stanToken.lockState(userA.address, 0)).to.deep.equal([timestamp, "1000000000000000000000"]);
            
            // lockStates
            expect(await stanToken.lockStates(userC.address)).to.deep.equal([[timestamp, "3000000000000000000000"], [timestamp, "4000000000000000000000"]]);
            
            expect(await stanToken.balanceOf(userA.address)).to.equal(0);
            expect(await stanToken.balanceOf(userB.address)).to.equal(0);
            expect(await stanToken.balanceOf(userC.address)).to.equal(0);
            
            expect(await stanToken.lockedBalanceOf(userA.address)).to.equal("1000000000000000000000");
            expect(await stanToken.lockedBalanceOf(userB.address)).to.equal("2000000000000000000000");
            expect(await stanToken.lockedBalanceOf(userC.address)).to.equal("7000000000000000000000");

            // stanToken Contract balanceOf
            expect(await stanToken.balanceOf(stanToken.target)).to.equal("10000000000000000000000");
        });

        // userA 에게 1000 STAN, userB 에게 2000 STAN, userC 에게 3000, 4000 STAN을 lock.
        // 그리고 userA 는 6개월 후 1000 STAN release
        // userB 는 12개월 후 2000 STAN release
        // userC 는 18개월 후 3000 STAN release
        // userC 는 24개월 후 4000 STAN release
        it("Should release the locked tokens for the users", async function () {
            const { stanToken, owner, userA, userB, userC } = await loadFixture(deployFixture);

            // approve
            stanToken.approve(owner.address, "10000000000000000000000");

            let currentTimestamp = await time.latest();

            await stanToken.lock(userA.address, "1000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 6);
            await stanToken.lockAfter(userB.address, "2000000000000000000000", 60 * 60 * 24 * 30 * 12);
            await stanToken.lock(userC.address, "3000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 18);
            await stanToken.lockAfter(userC.address, "4000000000000000000000", 60 * 60 * 24 * 30 * 24);
            
            // availableReleaseLock
            expect(await stanToken.estimateAmountToReleaseLock(userA.address)).to.equal("0");

            await time.increase(60 * 60 * 24 * 30 * 6);

            expect(await stanToken.estimateAmountToReleaseLock(userA.address)).to.equal("1000000000000000000000");

            await stanToken.release(userA.address);

            await time.increase(60 * 60 * 24 * 30 * 12);
            await stanToken.release(userB.address);

            await time.increase(60 * 60 * 24 * 30 * 18);
            await stanToken.release(userC.address);

            expect(await stanToken.balanceOf(userC.address)).to.equal("3000000000000000000000");
            expect(await stanToken.lockedBalanceOf(userC.address)).to.equal("4000000000000000000000");

            await time.increase(60 * 60 * 24 * 30 * 24);
            await stanToken.release(userC.address);

            expect(await stanToken.balanceOf(userA.address)).to.equal("1000000000000000000000");
            expect(await stanToken.balanceOf(userB.address)).to.equal("2000000000000000000000");
            expect(await stanToken.balanceOf(userC.address)).to.equal("7000000000000000000000");

            expect(await stanToken.lockedBalanceOf(userA.address)).to.equal(0);
            expect(await stanToken.lockedBalanceOf(userB.address)).to.equal(0);
            expect(await stanToken.lockedBalanceOf(userC.address)).to.equal(0);

            // stanToken Contract balanceOf
            expect(await stanToken.balanceOf(stanToken.target)).to.equal(0);
        });

        // cancelLock test
        it("Should cancel the locked tokens for the users", async function () {
            const { stanToken, owner, userA, userB, userC } = await loadFixture(deployFixture);

            // approve
            stanToken.approve(owner.address, "10000000000000000000000");

            let currentTimestamp = await time.latest();

            await stanToken.lock(userA.address, "1000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 6);
            await stanToken.lock(userB.address, "2000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 12);
            await stanToken.lock(userC.address, "3000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 18);
            await stanToken.lock(userC.address, "4000000000000000000000", currentTimestamp + 60 * 60 * 24 * 30 * 24);

            await time.increase(60 * 60 * 24 * 30 * 3);
            await stanToken.cancelLock(userA.address, 0);
            await stanToken.cancelLock(userB.address, 0);
            await stanToken.cancelLock(userC.address, 0);

            // release 시도
            await time.increase(60 * 60 * 24 * 30 * 3);

            // release 실패
            await expect(stanToken.release(userA.address)).to.be.revertedWith("No lock information.");
            await expect(stanToken.release(userB.address)).to.be.revertedWith("No lock information.");

            await stanToken.release(userC.address);
            // userC 는 24개월 후 4000 STAN release

            // userC의 STAN 잔액 확인
            expect(await stanToken.balanceOf(userC.address)).to.equal("0");
            // userC의 locked STAN 잔액 확인
            expect(await stanToken.lockedBalanceOf(userC.address)).to.equal("4000000000000000000000");

            // 18개월 후 (총 24개월 후)
            await time.increase(60 * 60 * 24 * 30 * 18);

            // userC release
            await stanToken.release(userC.address);

            // userC의 STAN 잔액 확인
            expect(await stanToken.balanceOf(userC.address)).to.equal("4000000000000000000000");
            // userC의 locked STAN 잔액 확인
            expect(await stanToken.lockedBalanceOf(userC.address)).to.equal("0");
        });
    });
});
  