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
    // function balanceOf(address _holder) public view override returns (uint256) {
    //     uint256 lockedBalance = 0;
    //     for(uint256 i = 0; i < lockInfo[_holder].length ; i++ ) {
    //         lockedBalance = lockedBalance + (lockInfo[_holder][i].balance);
    //     }
    //     return super.balanceOf(_holder) + lockedBalance;
    // }

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

    // release 하면 히스토리 남기기 위한 구조체
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

    // lock 된 정보 중 releaseTime이 지난 정보를 return (즉, Claim 가능한 수량)
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

    // 지금까지 claim 된 수량을 return
    function claimedTokens(address _holder) public view returns (uint256) {
        uint256 total = 0;
        for (uint256 i = 0; i < releasedHistory[_holder].length; i++) {
            total += releasedHistory[_holder][i].balance;
        }
        return total;
    }

    // msg.sender 한테 lock 된 정보가 있으면 releaseTime이 지났는지 확인하고 지났으면 수량을 전송
    function release(address _holder) external whenNotPaused nonReentrant {
        require(_holder == msg.sender || msg.sender == owner(), "Only the holder can release the lock.");
        require(!blacklist[_holder], "The user is frozen");
        require(lockInfo[_holder].length > 0, "No lock information.");

        // lockInfo[_holder].length 만큼 조회해서 전부 balance 가 0 이면 revert
        uint256 total = 0;
        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            if (lockInfo[_holder][i].balance == 0) {
                total += 1;
            }
        }
        require(total != lockInfo[_holder].length, "No claimable tokens.");

        for (uint256 i = 0; i < lockInfo[_holder].length; i++) {
            // releaseTime이 지났으면 수량을 전송
            // lockInfo는 releaseTime이 지난 것은 삭제하지 않고 balance만 0으로 처리

            // balance가 0이면 이미 release 된 것이므로 skip
            if (lockInfo[_holder][i].balance == 0) {
                continue;
            }

            if (lockInfo[_holder][i].releaseTime <= block.timestamp) {
                uint256 amount = lockInfo[_holder][i].balance;
                lockInfo[_holder][i].balance = 0;

                // ReleasedHistory 추가
                releasedHistory[_holder].push(
                    ReleasedHistory(block.timestamp, amount)
                );

                _transfer(address(this), _holder, amount);

                emit Claim(_holder, amount);
            }
        }


        

        // // 10개 중에서 6개 release time이 되었을 때 가정
        // uint256 len = lockInfo[_holder].length;
        // for (uint256 i = 0; i < len; i++) {
        //     console.log(i, "th lock is released. release time:", lockInfo[_holder][i].releaseTime);
        //     console.log("block.timestamp: ", block.timestamp);

        //     if (lockInfo[_holder][i].releaseTime <= block.timestamp) {
        //         uint256 amount = lockInfo[_holder][i].balance;
        //         lockInfo[_holder][i].balance = 0;
                
        //         // i == 0
        //         if (i != lockInfo[_holder].length - 1) {
        //             lockInfo[_holder][i] = lockInfo[_holder][lockInfo[_holder].length - 1];
        //         }
        //         lockInfo[_holder].pop();
                
        //         // ReleasedHistory 추가
        //         releasedHistory[_holder].push(
        //             ReleasedHistory(block.timestamp, amount)
        //         );

        //         _transfer(address(this), _holder, amount);
                
        //         emit Claim(_holder, amount);
        //     }
        // }
    }

    function lockCount(address _holder) public view returns (uint256) {
        return lockInfo[_holder].length;
    }

    function lockState(address _holder, uint256 _idx) public view returns (uint256, uint256) {
        console.log(lockInfo[_holder][_idx].releaseTime);
        console.log(lockInfo[_holder][_idx].balance);

        return (lockInfo[_holder][_idx].releaseTime, lockInfo[_holder][_idx].balance);
    }

    function consoleLine() public pure returns (string memory) {
        console.log("====================");
        return "====================";
    }

    function log(string memory _log) public pure returns (string memory) {
        console.log(_log);
        return _log;
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

    // lockCount 와 releasedHistoryCount 정보를 합쳐서 Total Lock 수량을 return
    function totalLocks(address _holder) public view returns (uint256) {
        return lockInfo[_holder].length + releasedHistory[_holder].length;
    }

    // lockInfo 와 releasedHistory 정보를 합쳐서 Total Vested Tokens 수량을 return
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

    // lock: owner 가 가지고 있던 STAN 수량을 STAN contract에게 전송하고, lock 정보를 추가(유저, 수량, releaseTime)
    // releaseTime이 되면 해당 유저는 lock 정보를 통해 STAN 수량을 받을 수 있음
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

    // unlock: lock 된 정보를 해제하고 STAN 수량을 다시 owner에게 전송 (vesting 취소 시 사용)
    function cancelLock(address _holder, uint256 i) public onlyOwner {
        require(i < lockInfo[_holder].length, "No lock information.");

        uint256 amount = lockInfo[_holder][i].balance;

        // 먼저 잔액이 충분한지 확인
        require(super.balanceOf(address(this)) >= amount, "STAN Balance is too small.");

        lockInfo[_holder][i].balance = 0;
        
        // if (i != lockInfo[_holder].length - 1) {
        //     lockInfo[_holder][i] = lockInfo[_holder][lockInfo[_holder].length - 1];
        // }
        // lockInfo[_holder].pop();

        


        // 취소 물량은 owner에게 전송(이미 this contract에게 전송되어 있음)
        // transferFrom(address(this), msg.sender, amount);
        // this contract balance 에서 owner에게 전송
        // transfer(address(this), msg.sender, amount);
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