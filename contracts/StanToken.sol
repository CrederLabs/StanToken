// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StanToken is ERC20, Ownable, Pausable {

    constructor() Ownable(msg.sender) ERC20("Station Token", "STAN") {
        _mint(msg.sender, 1000000000 * 10**uint(decimals()));
    }

    /* ========== ReentrancyGuard ========== */
    mapping (address => bool) private _locks;

    modifier nonReentrant {
        require(_locks[msg.sender] != true, "ReentrancyGuard: reentrant call");

        _locks[msg.sender] = true;

        _;
    
        _locks[msg.sender] = false;
    }

    /* ========== Freezable ========== */
    mapping(address => bool) blacklist;

    function freeze(address who) public onlyOwner {
        blacklist[who] = true;
        
        emit Frozen(who);
    }

    function unfreeze(address who) public onlyOwner {
        blacklist[who] = false;
        
        emit Unfrozen(who);
    }

    function isFrozen(address who) public view returns (bool) {
        return blacklist[who];
    }

    /* ========== ERC20 ========== */
    function transfer(address sender, address recipient, uint256 amount) internal virtual whenNotPaused returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "The user is frozen");
        super._transfer(sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override whenNotPaused returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "The user is frozen");
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    /* ========== Vesting ========== */
    struct LockInfo {
        uint256 releaseTime;
        uint256 balance;
    }

    mapping(address => LockInfo[]) internal lockInfo;

    struct ReleasedHistory {
        uint256 releaseTime;
        uint256 balance;
    }

    mapping(address => ReleasedHistory[]) internal releasedHistory;

    struct CancelHistory {
        uint256 cancelTime;
        uint256 balance;
    }

    mapping(address => CancelHistory[]) internal cancelHistory;

    // Remaining Tokens
    function remainingTokens(address _holder) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            total += lockInfo[_holder][i].balance;
        }
        return total;
    }

    // Return information from locked data where the releaseTime has passed (i.e., the amount that can be claimed).
    function claimableTokens(address _holder) public view returns (uint256) {
        uint256 total = 0;
        if (lockInfo[_holder].length > 0) {
            for (uint256 i = 0; i < lockInfo[_holder].length ; i++) {
                if (lockInfo[_holder][i].releaseTime <= block.timestamp) {
                    total += lockInfo[_holder][i].balance;
                }
            }
        }
        return total;
    }

    // Return the amount that has been claimed so far.
    function claimedTokens(address _holder) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < releasedHistory[_holder].length; i++) {
            total += releasedHistory[_holder][i].balance;
        }
        return total;
    }

    // Check if there is any locked information for `msg.sender`. If there is and the `releaseTime` has passed, transfer the amount to `msg.sender`.
    function release(address _holder) external whenNotPaused nonReentrant {
        require(_holder == msg.sender || msg.sender == owner(), "Only the holder can release the lock.");
        require(!blacklist[_holder], "The user is frozen");
        require(lockInfo[_holder].length > 0, "No lock information.");

        // Check all entries in `lockInfo[_holder]` by iterating through its length. If all balances are 0, revert the transaction.
        uint256 total = 0;
        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            if (lockInfo[_holder][i].balance == 0) {
                total += 1;
            }
        }
        require(total != lockInfo[_holder].length, "No claimable tokens.");

        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            // Send the quantity if the release time has passed.
            // For `lockInfo`, do not delete entries where the `releaseTime` has passed; instead, set the `balance` to 0.

            // If the `balance` is 0, it indicates that the amount has already been released, so skip that entry.
            if (lockInfo[_holder][i].balance == 0) {
                continue;
            }

            if (lockInfo[_holder][i].releaseTime <= block.timestamp) {
                uint256 amount = lockInfo[_holder][i].balance;
                lockInfo[_holder][i].balance = 0;

                // Add the entry to `ReleasedHistory`.
                releasedHistory[_holder].push(
                    ReleasedHistory(block.timestamp, amount)
                );

                _transfer(address(this), _holder, amount);

                emit Claim(_holder, amount);
            }
        }
    }

    function lockCount(address _holder) public view returns (uint256) {
        return lockInfo[_holder].length;
    }

    function lockState(address _holder, uint256 _idx) public view returns (uint256, uint256) {
        console.log(lockInfo[_holder][_idx].releaseTime);
        console.log(lockInfo[_holder][_idx].balance);

        return (lockInfo[_holder][_idx].releaseTime, lockInfo[_holder][_idx].balance);
    }

    function lockStates(address _holder) public view returns (LockInfo[] memory) {
        return lockInfo[_holder];
    }

    function lockStates2(address _holder) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory releaseTimes = new uint256[](lockInfo[_holder].length);
        uint256[] memory balances = new uint256[](lockInfo[_holder].length);

        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            releaseTimes[i] = lockInfo[_holder][i].releaseTime;
            balances[i] = lockInfo[_holder][i].balance;
        }

        return (releaseTimes, balances);
    }

    function releasedHistoryCount(address _holder) public view returns (uint256) {
        return releasedHistory[_holder].length;
    }

    function releasedHistoryState(address _holder, uint256 _idx) public view returns (uint256, uint256) {
        return (releasedHistory[_holder][_idx].releaseTime, releasedHistory[_holder][_idx].balance);
    }

    function releasedHistoryStates(address _holder) public view returns (ReleasedHistory[] memory) {
        return releasedHistory[_holder];
    }

    function releasedHistoryStates2(address _holder) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory releaseTimes = new uint256[](releasedHistory[_holder].length);
        uint256[] memory balances = new uint256[](releasedHistory[_holder].length);

        for (uint256 i = 0; i < releasedHistory[_holder].length; i++) {
            releaseTimes[i] = releasedHistory[_holder][i].releaseTime;
            balances[i] = releasedHistory[_holder][i].balance;
        }

        return (releaseTimes, balances);
    }

    // cancelHistory
    function cancelHistoryCount(address _holder) public view returns (uint256) {
        return cancelHistory[_holder].length;
    }

    function cancelHistoryState(address _holder, uint256 _idx) public view returns (uint256, uint256) {
        return (cancelHistory[_holder][_idx].cancelTime, cancelHistory[_holder][_idx].balance);
    }

    function cancelHistoryStates(address _holder) public view returns (CancelHistory[] memory) {
        return cancelHistory[_holder];
    }

    function cancelHistoryStates2(address _holder) public view returns (uint256[] memory, uint256[] memory) {
        uint256[] memory cancelTimes = new uint256[](cancelHistory[_holder].length);
        uint256[] memory balances = new uint256[](cancelHistory[_holder].length);

        for (uint256 i = 0; i < cancelHistory[_holder].length; i++) {
            cancelTimes[i] = cancelHistory[_holder][i].cancelTime;
            balances[i] = cancelHistory[_holder][i].balance;
        }

        return (cancelTimes, balances);
    }

    // Combine the `lockCount` and `releasedHistoryCount` to return the total locked quantity.
    function totalLocks(address _holder) public view returns (uint256) {
        return lockInfo[_holder].length + releasedHistory[_holder].length;
    }

    // Combine the `lockInfo` and `releasedHistory` data to return the total amount of vested tokens.
    function totalVestedTokens(address _holder) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            total += lockInfo[_holder][i].balance;
        }
        for (uint256 i = 0; i < releasedHistory[_holder].length; i++) {
            total += releasedHistory[_holder][i].balance;
        }
        return total;
    }

    // For the lock function:
    //     1. The owner transfers a specified amount of STAN tokens they hold to the STAN contract.
    //     2. Add lock information, including the user address, the amount, and the `releaseTime`.
    // When the `releaseTime` is reached, the user can claim the STAN tokens based on the lock information.
    function lock(address _to, uint256 _amount, uint256 _releaseTime) public onlyOwner {
        require(super.balanceOf(msg.sender) >= _amount, "Balance is too small.");
        require(_releaseTime > block.timestamp, "Release time should be in the future");
        
        transferFrom(msg.sender, address(this), _amount);
        lockInfo[_to].push(
            LockInfo(_releaseTime, _amount)
        );
        emit Lock(_to, _amount, _releaseTime);
    }

    function lockAfter(address _to, uint256 _amount, uint256 _afterTime) public onlyOwner {
        require(super.balanceOf(msg.sender) >= _amount, "Balance is too small.");

        transferFrom(msg.sender, address(this), _amount);
        lockInfo[_to].push(
            LockInfo(block.timestamp + _afterTime, _amount)
        );
        emit Lock(_to, _amount, block.timestamp + _afterTime);
    }

    // For the unlock function:
    //     1. Unlock the locked information.
    //     2. Transfer the STAN tokens back to the owner. (This is used when the vesting is canceled.)
    function cancelLock(address _holder, uint256 i) public onlyOwner {
        require(i < lockInfo[_holder].length, "No lock information.");

        uint256 amount = lockInfo[_holder][i].balance;

        require(super.balanceOf(address(this)) >= amount, "STAN Balance is too small.");

        lockInfo[_holder][i].balance = 0;

        // The canceled amount is transferred back to the owner (since it has already been transferred to this contract).
        _transfer(address(this), msg.sender, amount);

        emit CancelLock(_holder, amount);
    }

    /* ========== TIME ========== */
    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function afterTime(uint256 _value) public view returns (uint256) {
        return block.timestamp + _value;
    }

    /* ========== Recovery ========== */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) public onlyOwner {
        IERC20(tokenAddress).transfer(owner(), tokenAmount);
    }

    function recoverETH(uint256 amount) public onlyOwner {
        payable(owner()).transfer(amount);
    }

    /* ========== EVENTS ========== */
    event Frozen(address indexed who);
    event Unfrozen(address indexed who);

    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event CancelLock(address indexed holder, uint256 value);
    event Claim(address indexed holder, uint256 value);
}