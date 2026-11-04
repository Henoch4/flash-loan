// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

abstract contract ReentrancyGuard {
    bool private _nonReentrant;
    constructor() { _nonReentrant = false; }
    modifier nonReentrant() {
        require(!_nonReentrant, "ReentrancyGuard: reentrant call");
        _nonReentrant = true;
        _;
        _nonReentrant = false;
    }
}
abstract contract Ownable {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    constructor() { _owner = msg.sender; emit OwnershipTransferred(address(0), _owner); }
    modifier onlyOwner() { require(_owner == msg.sender, "Ownable: caller is not the owner"); _; }
    function owner() public view returns (address) { return _owner; }
}

interface INativeFlashReceiver {
    function onFlashLoan(address initiator,uint256 amount,uint256 fee,bytes calldata data) external payable returns(bytes32);
}
contract FlashLoan is ReentrancyGuard, Ownable {
    struct Loan {
        address borrower;
        uint256 amount;
        uint256 feeBps;
        uint256 timestamp;
        bool executed;
    }
    Loan[] public loans;
    uint256 public totalVolume;
    uint256 public totalFees;
    uint256 public defaultFeeBps = 9;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("BOTChain.NativeFlashLoan");

    event LoanRequested(uint256 indexed lid, address indexed borrower, uint256 amount, uint256 feeBps);
    event LoanExecuted(uint256 indexed lid, address indexed borrower, uint256 amount, uint256 fee);
    event LoanFailed(uint256 indexed lid, address indexed borrower, uint256 amount);
    event VaultFunded(address indexed funder, uint256 amount);
    event FeesWithdrawn(address indexed to, uint256 amount);

    event AtomicLoanExecuted(address indexed initiator,address indexed receiver,uint256 amount,uint256 fee);
    receive() external payable {}
    function setDefaultFee(uint256 bps) external onlyOwner { require(bps<=1000,"Fee exceeds 10 percent");defaultFeeBps = bps; }

    // FIX: there was no funding mechanism at all, so a flash loan could never be
    // honoured. Owner (demo treasury) seeds the vault; everything repaid stays here.
    function fundVault() external payable onlyOwner nonReentrant {
        require(msg.value > 0, "Zero amount");
        emit VaultFunded(msg.sender, msg.value);
    }

    // FIX: fees were only credited to a paper counter that no one could touch.
    // Fees now physically remain in the vault and the owner can withdraw them.
    function withdraw(uint256 amount, address payable to) external onlyOwner nonReentrant {
        require(to != address(0), "Zero address");
        require(address(this).balance >= amount, "Insufficient balance");
        (bool ok, ) = to.call{value: amount}("");
        require(ok, "ETH transfer failed");
        emit FeesWithdrawn(to, amount);
    }

    function requestFlashLoan(uint256 amount, uint256 feeBps) external nonReentrant returns (uint256) {
        require(amount > 0, "Zero amount");
        require(feeBps <= 1000, "Fee exceeds 10 percent");
        Loan storage l = loans.push();
        l.borrower = msg.sender;
        l.amount = amount;
        l.feeBps = feeBps > 0 ? feeBps : defaultFeeBps;
        l.timestamp = block.timestamp;
        l.executed = false;
        uint256 lid = loans.length - 1;
        emit LoanRequested(lid, msg.sender, amount, l.feeBps);
        return lid;
    }

    function executeFlashLoan(uint256 lid) external nonReentrant {
        Loan storage l = loans[lid];
        require(!l.executed, "Already executed");
        require(l.borrower == msg.sender, "Not your loan");
        l.executed = true;
        uint256 fee = _execute(msg.sender,msg.sender,l.amount,l.feeBps,"");
        emit LoanExecuted(lid, msg.sender, l.amount, fee);
    }

    function flashLoan(address receiver,uint256 amount,bytes calldata data) external nonReentrant {
        _execute(receiver,msg.sender,amount,defaultFeeBps,data);
    }
    function _execute(address receiver,address initiator,uint256 amount,uint256 feeBps,bytes memory data) private returns(uint256 fee) {
        require(receiver.code.length>0&&amount>0,"Invalid receiver or amount");
        uint256 beforeBalance=address(this).balance;
        require(amount<=beforeBalance,"Insufficient vault");
        fee=(amount*feeBps+9999)/10000;
        require(INativeFlashReceiver(receiver).onFlashLoan{value:amount}(initiator,amount,fee,data)==CALLBACK_SUCCESS,"Invalid callback");
        require(address(this).balance>=beforeBalance+fee,"Principal and fee not repaid");
        totalVolume+=amount;totalFees+=fee;
        emit AtomicLoanExecuted(initiator,receiver,amount,fee);
    }

    function failFlashLoan(uint256 lid) external {
        // FIX: kept as an explicit abandon flag. Safe because no funds ever move
        // until executeFlashLoan, which atomically requires repayment.
        Loan storage l = loans[lid];
        require(!l.executed, "Already executed");
        require(l.borrower == msg.sender, "Not your loan");
        l.executed = true;
        emit LoanFailed(lid, msg.sender, l.amount);
    }

    function getLoan(uint256 lid) external view returns (address borrower, uint256 amount, uint256 feeBps, uint256 timestamp, bool executed) {
        Loan storage l = loans[lid];
        return (l.borrower, l.amount, l.feeBps, l.timestamp, l.executed);
    }
}
