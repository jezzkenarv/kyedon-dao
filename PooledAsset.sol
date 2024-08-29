// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PooledAsset is Ownable {
    IERC20 public token;
    uint256 public totalSupply;
    uint256 public loanToValueRatio;
    uint256 public minimumDepositAmount;
    uint256 public contributionFrequency;
    uint256 public maximumPoolSize;
    uint256 public premiumRate;
    uint256 public feeRate;

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

    // Additional functions for pool management, deposits, withdrawals, etc. will be implemented here
}
