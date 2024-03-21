// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Box is Ownable {
    constructor() Ownable(msg.sender) {}

    uint256 private s_number;

    event NumberChanged(uint256 _number);

    function store(uint256 _newNumber) public onlyOwner {
        s_number = _newNumber;
        emit NumberChanged(_newNumber);
    }
}
