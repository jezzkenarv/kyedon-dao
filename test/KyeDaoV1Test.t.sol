// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {KyeDaoRotatingRound} from "../src/KyeDaoV1.sol"; 

contract KyeDaoV1Test is KyeDaoRotatingRound {
    constructor() KyeDaoRotatingRound() {
        token = IERC20(0x0);
        contributionAmount = 100;
        roundDuration = 1 days;
        currentRound = 0;
    }

    function testDeposit() public {
       
    }
}

