// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// Uncomment this line to use console.log
// import "hardhat/console.sol";

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StanToken is ERC20, Ownable, Pausable {

    constructor() Ownable(msg.sender) ERC20("Station Token", "STAN") {
        _mint(msg.sender, 1000000000 * 10**uint(decimals()));
    }

    /* ========== ReentrancyGuard ========== */
    // mapping (address => bool) private _locks;

    // modifier nonReentrant {
    //     require(_locks[msg.sender] != true, "ReentrancyGuard: reentrant call");

    //     _locks[msg.sender] = true;

    //     _;
    
    //     _locks[msg.sender] = false;
    // }

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
    function balanceOf(address _holder) public view override returns (uint256) {
        uint256 lockedBalance = 0;
        for(uint256 i = 0; i < lockInfo[_holder].length ; i++ ) {
            lockedBalance = lockedBalance + (lockInfo[_holder][i].balance);
        }
        return super.balanceOf(_holder) + lockedBalance;
    }

    function transfer(address sender, address recipient, uint256 amount) internal virtual whenNotPaused returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "The user is frozen");
        releaseLock(msg.sender);
        super._transfer(sender, recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override whenNotPaused returns (bool) {
        require(!blacklist[sender] && !blacklist[recipient], "The user is frozen");
        releaseLock(sender);
        super.transferFrom(sender, recipient, amount);
        return true;
    }

    /* ========== Vesting ========== */
    struct LockInfo {
        uint256 releaseTime;
        uint256 balance;
    }

    mapping(address => LockInfo[]) internal lockInfo;

    function lockBalanceOf(address holder) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < lockInfo[holder].length; i++) {
            total += lockInfo[holder][i].balance;
        }
        return total;
    }

    function releaseLock(address _holder) internal {
        if (lockInfo[_holder].length > 0) {
            for (uint256 i = 0; i < lockInfo[_holder].length ; i++) {
                if (lockInfo[_holder][i].releaseTime <= block.timestamp) {
                    // _balances[_holder] = _balances[_holder].add(lockInfo[_holder][i].balance);
                    // TODO: lockInfo[_holder][i].balance 수량을 _holder에게 전송
                    _transfer(address(this), _holder, lockInfo[_holder][i].balance);
                    emit Unlock(_holder, lockInfo[_holder][i].balance);
                    lockInfo[_holder][i].balance = 0;

                    if (i != lockInfo[_holder].length - 1) {
                        lockInfo[_holder][i] = lockInfo[_holder][lockInfo[_holder].length - 1];
                    }
                    lockInfo[_holder].pop();
                }
            }
        }
    }

    function lockCount(address _holder) public view returns (uint256) {
        return lockInfo[_holder].length;
    }

    function lockState(address _holder, uint256 _idx) public view returns (uint256, uint256) {
        return (lockInfo[_holder][_idx].releaseTime, lockInfo[_holder][_idx].balance);
    }

    function lock(address _holder, uint256 _amount, uint256 _releaseTime) public onlyOwner {
        require(super.balanceOf(_holder) >= _amount, "Balance is too small.");
        require(_releaseTime > block.timestamp, "Release time should be in the future");

        // _balances[_holder] = _balances[_holder].sub(_amount);
        transferFrom(_holder, address(this), _amount);
        lockInfo[_holder].push(
            LockInfo(_releaseTime, _amount)
        );
        emit Lock(_holder, _amount, _releaseTime);
    }

    function lockAfter(address _holder, uint256 _amount, uint256 _afterTime) public onlyOwner {
        require(super.balanceOf(_holder) >= _amount, "Balance is too small.");
        // _balances[_holder] = _balances[_holder].sub(_amount);
        transferFrom(_holder, address(this), _amount);
        lockInfo[_holder].push(
            LockInfo(block.timestamp + _afterTime, _amount)
        );
        emit Lock(_holder, _amount, block.timestamp + _afterTime);
    }

    function unlock(address _holder, uint256 i) public onlyOwner {
        require(i < lockInfo[_holder].length, "No lock information.");

        // _balances[_holder] = _balances[_holder].add(lockInfo[_holder][i].balance);
        _transfer(address(this), _holder, lockInfo[_holder][i].balance);

        emit Unlock(_holder, lockInfo[_holder][i].balance);
        lockInfo[_holder][i].balance = 0;

        if (i != lockInfo[_holder].length - 1) {
            lockInfo[_holder][i] = lockInfo[_holder][lockInfo[_holder].length - 1];
        }
        // lockInfo[_holder].length--;
        lockInfo[_holder].pop();
    }

    function transferWithLock(address _to, uint256 _value, uint256 _releaseTime) public onlyOwner returns (bool) {
        require(_to != address(0), "wrong address");
        require(_value <= super.balanceOf(msg.sender), "Not enough balance");

        // _balances[owner] = _balances[owner].sub(_value);
        transferFrom(msg.sender, address(this), _value);

        lockInfo[_to].push(
            LockInfo(_releaseTime, _value)
        );
        emit Transfer(msg.sender, _to, _value);
        emit Lock(_to, _value, _releaseTime);

        return true;
    }

    function transferWithLockAfter(address _to, uint256 _value, uint256 _afterTime) public onlyOwner returns (bool) {
        require(_to != address(0), "wrong address");
        require(_value <= super.balanceOf(msg.sender), "Not enough balance");

        // _balances[owner] = _balances[owner].sub(_value);
        transferFrom(msg.sender, address(this), _value);

        lockInfo[_to].push(
            LockInfo(block.timestamp + _afterTime, _value)
        );
        emit Transfer(msg.sender, _to, _value);
        emit Lock(_to, _value, block.timestamp + _afterTime);

        return true;
    }

    /* ========== TIME ========== */
    function currentTime() public view returns (uint256) {
        return block.timestamp;
    }

    function afterTime(uint256 _value) public view returns (uint256) {
        return block.timestamp + _value;
    }

    /* ========== EVENTS ========== */
    event Frozen(address indexed who);
    event Unfrozen(address indexed who);

    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event Unlock(address indexed holder, uint256 value);
}