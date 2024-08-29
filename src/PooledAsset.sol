// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract PooledAsset is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    uint256 public totalSupply;
    uint256 public loanToValueRatio;
    uint256 public minimumDepositAmount;
    uint256 public contributionFrequency;
    uint256 public maximumPoolSize;
    uint256 public premiumRate;
    uint256 public feeRate;
    uint256 public currentRound;

    struct Participant {
        uint256 balance;
        uint256 lastContributionRound;
        bool hasReceivedPayout;
    }

    struct Round {
        uint256 startTime;
        uint256 endTime;
        address payoutRecipient;
        bool isComplete;
        uint256 totalContributions;
    }

    mapping(address => Participant) public participants;
    mapping(uint256 => Round) public rounds;

    event Deposit(address indexed user, uint256 amount);
    event Withdrawal(address indexed user, uint256 amount);
    event NewRoundStarted(uint256 indexed roundNumber, uint256 startTime, uint256 endTime);
    event PayoutDistributed(address indexed recipient, uint256 amount);

    constructor(
        address _tokenAddress,
        uint256 _initialSupply,
        uint256 _loanToValueRatio,
        uint256 _minimumDepositAmount,
        uint256 _contributionFrequency,
        uint256 _maximumPoolSize,
        uint256 _premiumRate,
        uint256 _feeRate
    ) {
        token = IERC20(_tokenAddress);
        totalSupply = _initialSupply;
        loanToValueRatio = _loanToValueRatio;
        minimumDepositAmount = _minimumDepositAmount;
        contributionFrequency = _contributionFrequency;
        maximumPoolSize = _maximumPoolSize;
        premiumRate = _premiumRate;
        feeRate = _feeRate;
        currentRound = 0;

        // Start the first round
        startNewRound();
    }

    function deposit(uint256 _amount) external nonReentrant {
        require(_amount >= minimumDepositAmount, "Deposit amount too low");
        require(totalSupply + _amount <= maximumPoolSize, "Pool size limit reached");

        token.safeTransferFrom(msg.sender, address(this), _amount);
        participants[msg.sender].balance += _amount;
        totalSupply += _amount;

        emit Deposit(msg.sender, _amount);
    }

    function withdraw(uint256 _amount) external nonReentrant {
        require(participants[msg.sender].balance >= _amount, "Insufficient balance");
        require(participants[msg.sender].hasReceivedPayout, "Cannot withdraw before receiving payout");

        participants[msg.sender].balance -= _amount;
        totalSupply -= _amount;
        token.safeTransfer(msg.sender, _amount);

        emit Withdrawal(msg.sender, _amount);
    }

    function contribute() external nonReentrant {
        require(participants[msg.sender].balance >= minimumDepositAmount, "Insufficient balance to contribute");
        require(participants[msg.sender].lastContributionRound < currentRound, "Already contributed this round");

        uint256 contributionAmount = minimumDepositAmount;
        participants[msg.sender].lastContributionRound = currentRound;
        rounds[currentRound].totalContributions += contributionAmount;

        emit Deposit(msg.sender, contributionAmount);
    }

    function startNewRound() public onlyOwner {
        require(block.timestamp >= rounds[currentRound].endTime, "Current round not finished");
        
        currentRound++;
        rounds[currentRound] = Round({
            startTime: block.timestamp,
            endTime: block.timestamp + contributionFrequency,
            payoutRecipient: address(0),
            isComplete: false,
            totalContributions: 0
        });

        emit NewRoundStarted(currentRound, rounds[currentRound].startTime, rounds[currentRound].endTime);
    }

    function distributePayout() external onlyOwner {
        require(!rounds[currentRound].isComplete, "Round already completed");
        require(rounds[currentRound].totalContributions > 0, "No contributions in this round");

        address payoutRecipient = getNextPayoutRecipient();
        require(payoutRecipient != address(0), "No eligible recipient found");

        uint256 payoutAmount = rounds[currentRound].totalContributions;
        rounds[currentRound].payoutRecipient = payoutRecipient;
        rounds[currentRound].isComplete = true;
        participants[payoutRecipient].hasReceivedPayout = true;

        token.safeTransfer(payoutRecipient, payoutAmount);

        emit PayoutDistributed(payoutRecipient, payoutAmount);
    }

    function getNextPayoutRecipient() internal view returns (address) {
        address[] memory allParticipants = getAllParticipants();
        for (uint256 i = 0; i < allParticipants.length; i++) {
            address participant = allParticipants[i];
            if (participants[participant].balance > 0 && !participants[participant].hasReceivedPayout) {
                return participant;
            }
        }
        return address(0);
    }

    function getAllParticipants() public view returns (address[] memory) {
        // This function should return an array of all participant addresses
        // Implementation left as an exercise
        revert("Not implemented");
    }

    function setLoanToValueRatio(uint256 _newRatio) external onlyOwner {
        require(_newRatio > 0 && _newRatio <= 100, "Invalid loan to value ratio");
        loanToValueRatio = _newRatio;
    }

    function setMinimumDepositAmount(uint256 _newAmount) external onlyOwner {
        require(_newAmount > 0, "Invalid minimum deposit amount");
        minimumDepositAmount = _newAmount;
    }

    function setContributionFrequency(uint256 _newFrequency) external onlyOwner {
        require(_newFrequency > 0, "Invalid contribution frequency");
        contributionFrequency = _newFrequency;
    }

    function setMaximumPoolSize(uint256 _newSize) external onlyOwner {
        require(_newSize > totalSupply, "Maximum pool size must be greater than total supply");
        maximumPoolSize = _newSize;
    }

    function setPremiumRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 10000, "Premium rate must be <= 10000 (100%)");
        premiumRate = _newRate;
    }

    function setFeeRate(uint256 _newRate) external onlyOwner {
        require(_newRate <= 10000, "Fee rate must be <= 10000 (100%)");
        feeRate = _newRate;
    }

    function getParticipantInfo(address participant) external view returns (Participant memory) {
        return participants[participant];
    }

    function getRoundInfo(uint256 roundNumber) external view returns (Round memory) {
        return rounds[roundNumber];
    }
}
