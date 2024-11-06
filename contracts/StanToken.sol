// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

contract StanToken is ERC20, Pausable {
    using SafeERC20 for IERC20;

    // The signer is responsible for authorizing the execution of critical functions of the STAN token.
    // setBlockInterval, freeze, unfreeze, lock, lockAfter, cancelLock, recoverERC20, recoverETH 등의 함수를 실행하기 위해서는 signers에 등록된 주소로부터 서명을 받아야 한다.
    address[] public signers;

    /* ========== Transaction Request ========== */
    struct TransactionRequest {
        address proposer;
        string functionName;
        address address1;
        address address2;
        uint256 number1;
        uint256 number2;
        mapping (address => bool) confirmedBy;
    }

    // The data combined from the parameters entered by the user is converted to bytes and used as a UUID.
    mapping (bytes32 => TransactionRequest) public transactionRequests;

    struct TransactionRequestHistory {
        bytes32 uuid;
        address proposer;
        string functionName;
        address address1;
        address address2;
        uint256 number1;
        uint256 number2;
    }

    TransactionRequestHistory[] public transactionRequestHistory;

    bytes32[] public uuids;

    mapping (bytes32 => mapping (address => uint256)) tempLockAmount;

    constructor() ERC20("Station Token", "STAN") {
        _mint(msg.sender, 1000000000 * 10**uint(decimals()));
        
        signers.push(msg.sender);
    }

    /* ========== ReentrancyGuard ========== */
    mapping (address => bool) private _locks;

    modifier nonReentrantDirect() {
        require(msg.sender == tx.origin, "Direct calls only");
        require(!_locks[msg.sender], "ReentrancyGuard: reentrant call");

        _locks[msg.sender] = true;
        _;
        _locks[msg.sender] = false;
    }

    /* ========== Signer ========== */
    modifier onlySigner() {
        bool isSigner = false;
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        require(isSigner, "Only signer");
        _;
    }

    function addSigner(address _signer) public onlySigner {
        require(_signer != address(0), "Invalid address");
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                require(false, "Already added");
            }
        }

        if (!confirmSignature("addSigner", _signer, address(0), 0, 0)) return;

        signers.push(_signer);
        emit SignerAdded(_signer);
    }

    // Multiple addresses can be added at once using the `addSigners` function.
    function addSigners(address[] memory _signers) public onlySigner {
        require(_signers.length > 0, "Invalid addresses");

        for (uint256 i = 0; i < _signers.length; i++) {
            require(_signers[i] != address(0), "Invalid address");
            for (uint256 j = 0; j < signers.length; j++) {
                require(signers[j] != _signers[i], "Already added");
            }
        }

        // Combine `_signers` into a `bytes32` format and then convert it to an `address`.
        bytes32 signersBytes32 = keccak256(abi.encodePacked(_signers));
        address signersBytes32ToAddress = address(uint160(uint256(signersBytes32)));

        if (!confirmSignature("addSigner", signersBytes32ToAddress, address(0), 0, 0)) return;

        for (uint256 i = 0; i < _signers.length; i++) {
            addSigner(_signers[i]);
            emit SignerAdded(_signers[i]);
        }
    }

    function removeSigner(address _signer) public onlySigner {
        require(signers.length > 1, "Cannot remove the last signer");

        if (!confirmSignature("removeSigner", _signer, address(0), 0, 0)) return;
        
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                signers[i] = signers[signers.length - 1];
                signers.pop();
                break;
            }
        }

        emit SignerRemoved(_signer);
    }

    function isSigner(address _signer) public view returns (bool) {
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == _signer) {
                return true;
            }
        }
        return false;
    }

    function signersLength() public view returns (uint256) {
        return signers.length;
    }

    /* ========== Block Interval ========== */
    // In Avalanche, 1 block is produced every 2 seconds.
    // The signatures from the signers must be completed within 100,000 blocks to execute.
    // 100,000 blocks = 55.55 hours (approximately 2.3 days).
    // Calculate in units of 100,000 by setting the lower 5 digits of `block.number` to zero.
    uint256 public BLOCK_INTERVAL = 100000;

    function setBlockInterval(uint256 _blockInterval) public onlySigner {
        require(_blockInterval != 0, "Invalid block interval");

        if (!confirmSignature("setBlockInterval", address(0), address(0), _blockInterval, 0)) return;
        
        BLOCK_INTERVAL = _blockInterval;

        emit SetBlockInterval(_blockInterval);
    }

    function currentNonce() public view returns (uint256) {
        return block.number / BLOCK_INTERVAL;
    }

    function getNonce(uint256 blockNumber) public view returns (uint256) {
        return blockNumber / BLOCK_INTERVAL;
    }

    /* ========== Signer Threshold ========== */
    function confirmThreshold() internal view returns (uint256) {
        return (signers.length + 1) / 2;
    }

    /* ========== Signature ========== */
    function confirmSignature(string memory functionName, address address1, address address2, uint256 number1, uint256 number2) internal returns (bool) {
        bytes32 uuid = convertUuid(currentNonce(), functionName, address1, address2, number1, number2);
        TransactionRequest storage request = transactionRequests[uuid];

        if (request.proposer == address(0)) {
            // The `lock` and `lockAfter` functions allow the proposer to initiate the first transfer of tokens.
            if (keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("lock")) || 
                keccak256(abi.encodePacked(functionName)) == keccak256(abi.encodePacked("lockAfter"))) {
                require(super.balanceOf(msg.sender) >= number1, "Balance is too small.");
                transferFrom(msg.sender, address(this), number1);
                tempLockAmount[uuid][msg.sender] = number1;
            }

            request.proposer = msg.sender;
            request.functionName = functionName;
            request.address1 = address1;
            request.address2 = address2;
            request.number1 = number1;
            request.number2 = number2;
        }

        request.confirmedBy[msg.sender] = true;
        // 모든 uuid 는 기록 되어야 한다.
        uuids.push(uuid);
        emit SignatureConfirmed(uuid, functionName, address1, address2, number1, number2, msg.sender);

        uint256 confirmedCount = 0;
        for (uint256 i = 0; i < signers.length; i++) {
            if (request.confirmedBy[signers[i]]) {
                confirmedCount++;
            }
        }

        if (confirmedCount == confirmThreshold()) {
            transactionRequestHistory.push(
                TransactionRequestHistory(uuid, request.proposer, request.functionName, request.address1, request.address2, request.number1, request.number2)
            );
            delete transactionRequests[uuid];
            return true;
        } else {
            return false;
        }
    }

    function cancelSignature(bytes32 uuid) external onlySigner nonReentrantDirect {
        TransactionRequest storage request = transactionRequests[uuid];
        require(request.proposer == msg.sender, "Only proposer can cancel the transaction request.");
        
        if (keccak256(abi.encodePacked(request.functionName)) == keccak256(abi.encodePacked("lock")) || 
            keccak256(abi.encodePacked(request.functionName)) == keccak256(abi.encodePacked("lockAfter"))) {
            if (tempLockAmount[uuid][msg.sender] > 0) {
                IERC20(address(this)).safeTransfer(msg.sender, tempLockAmount[uuid][msg.sender]);
                delete tempLockAmount[uuid][msg.sender];
            }
        }

        delete transactionRequests[uuid];
    }

    function getUuidsCount() public view returns (uint256) {
        return uuids.length;
    }

    function getUuids(uint256 _idx) public view returns (bytes32) {
        return uuids[_idx];
    }

    function convertUuid(uint256 blockNumber, string memory functionName, address address1, address address2, uint256 number1, uint256 number2) public view returns (bytes32) {
        return keccak256(abi.encodePacked(getNonce(blockNumber), functionName, address1, address2, number1, number2));
    }
    
    function getTransactionRequestState(bytes32 uuid) public view returns (address, string memory, address, address, uint256, uint256) {
        TransactionRequest storage request = transactionRequests[uuid];
        return (request.proposer, request.functionName, request.address1, request.address2, request.number1, request.number2);
    }

    function getTransactionRequestHistoryCount() public view returns (uint256) {
        return transactionRequestHistory.length;
    }

    function getTransactionRequestHistoryState(uint256 _idx) public view returns (bytes32, address, string memory, address, address, uint256, uint256) {
        TransactionRequestHistory storage history = transactionRequestHistory[_idx];
        return (history.uuid, history.proposer, history.functionName, history.address1, history.address2, history.number1, history.number2);
    }

    /* ========== Freezable ========== */
    mapping(address => bool) blacklist;

    function freeze(address who) public onlySigner {
        if (!confirmSignature("freeze", who, address(0), 0, 0)) return;

        blacklist[who] = true;
        
        emit Frozen(who);
    }

    function unfreeze(address who) public onlySigner {
        if (!confirmSignature("unfreeze", who, address(0), 0, 0)) return;

        blacklist[who] = false;
        
        emit Unfrozen(who);
    }

    function isFrozen(address who) public view returns (bool) {
        return blacklist[who];
    }

    /* ========== Transfer Overrides ========== */
    // it need to add 'virtual' to ERC20's _transfer function
    function _transfer(address sender, address recipient, uint256 amount) internal override {
        require(!paused(), "Token transfer while paused");
        require(!blacklist[sender] && !blacklist[recipient], "Sender or recipient is frozen");
        super._transfer(sender, recipient, amount);
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
    function release(address _holder) external whenNotPaused nonReentrantDirect {
        bool isSigner = false;
        for (uint256 i = 0; i < signers.length; i++) {
            if (signers[i] == msg.sender) {
                isSigner = true;
                break;
            }
        }
        require(_holder == msg.sender || isSigner, "Only the holder or signer can release the lock.");
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
    function lock(address _to, uint256 _amount, uint256 _releaseTime) public onlySigner {
        // require(super.balanceOf(msg.sender) >= _amount, "Balance is too small.");
        require(_releaseTime > block.timestamp, "Release time should be in the future");

        if (!confirmSignature("lock", _to, address(0), _amount, _releaseTime)) return;
        
        lockInfo[_to].push(
            LockInfo(_releaseTime, _amount)
        );
        emit Lock(_to, _amount, _releaseTime);
    }

    function lockAfter(address _to, uint256 _amount, uint256 _afterTime) public onlySigner {
        require(super.balanceOf(msg.sender) >= _amount, "Balance is too small.");

        if (!confirmSignature("lockAfter", _to, address(0), _amount, _afterTime)) return;

        lockInfo[_to].push(
            LockInfo(block.timestamp + _afterTime, _amount)
        );
        emit Lock(_to, _amount, block.timestamp + _afterTime);
    }

    // For the unlock function:
    //     1. Unlock the locked information.
    //     2. Transfer the STAN tokens back to the owner. (This is used when the vesting is canceled.)
    function cancelLock(address _holder, uint256 i, address _receiver) public onlySigner nonReentrantDirect {
        require(i < lockInfo[_holder].length, "No lock information.");
        uint256 amount = lockInfo[_holder][i].balance;
        require(amount > 0, "No locked tokens.");
        require(super.balanceOf(address(this)) >= amount, "STAN Balance is too small.");
        require(_receiver != address(0), "Invalid address");

        if (!confirmSignature("cancelLock", _holder, _receiver, i, 0)) return;
        
        lockInfo[_holder][i].balance = 0;

        cancelHistory[_holder].push(CancelHistory(block.timestamp, amount));

        // The canceled amount is transferred back to the owner (since it has already been transferred to this contract).
        _transfer(address(this), _receiver, amount);

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
    function recoverERC20(address receiver, address tokenAddress, uint256 tokenAmount) public onlySigner {
        if (!confirmSignature("recoverERC20", receiver, tokenAddress, tokenAmount, 0)) return;

        IERC20(tokenAddress).safeTransfer(receiver, tokenAmount);

        emit RecoverERC20(receiver, tokenAddress, tokenAmount);
    }

    function recoverETH(address receiver, uint256 amount) public onlySigner {
        if (!confirmSignature("recoverETH", receiver, address(0), amount, 0)) return;

        payable(receiver).transfer(amount);

        emit RecoverETH(receiver, amount);
    }

    /* ========== EVENTS ========== */
    event Frozen(address indexed who);
    event Unfrozen(address indexed who);
    event Lock(address indexed holder, uint256 value, uint256 releaseTime);
    event CancelLock(address indexed holder, uint256 value);
    event Claim(address indexed holder, uint256 value);
    event SignatureConfirmed(bytes32 uuid, string functionName, address address1, address address2, uint256 number1, uint256 number2, address indexed signer);
    event SignerAdded(address indexed signer);
    event SignerRemoved(address indexed signer);
    event SetBlockInterval(uint256 blockInterval);
    event RecoverERC20(address indexed receiver, address indexed tokenAddress, uint256 tokenAmount);
    event RecoverETH(address indexed receiver, uint256 amount);
}