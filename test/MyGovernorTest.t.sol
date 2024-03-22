// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "@forge-std/Test.sol";
import {MyGovernor} from "../src/contracts/MyGovernor.sol";
import {Box} from "../src/contracts/Box.sol";
import {TimeLock} from "../src/contracts/TimeLock.sol";
import {GovToken} from "../src/contracts/GovToken.sol";
import {GovernorCountingSimple} from "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";

contract MyGovernorTest is Test {
    MyGovernor governor;
    Box box;
    TimeLock timeLock;
    GovToken govToken;

    uint256 public constant INITIAL_SUPPLY = 100 ether;
    uint256 public constant MIN_DELAY = 3600;
    uint256 public constant VOTING_DELAY = 1;
    uint256 public constant VOTING_PERIOD = 50400;
    address public USER = makeAddr("user");

    address[] proposers;
    address[] executors;
    bytes[] calldatas;
    uint256[] values;
    address[] targets;

    function setUp() public {
        govToken = new GovToken();
        govToken.mint(USER, INITIAL_SUPPLY);

        vm.startPrank(USER);
        govToken.delegate(USER);

        timeLock = new TimeLock(MIN_DELAY, proposers, executors);
        governor = new MyGovernor(govToken, timeLock);

        bytes32 proposerRole = timeLock.PROPOSER_ROLE();
        bytes32 executorRole = timeLock.EXECUTOR_ROLE();
        bytes32 adminRole = timeLock.DEFAULT_ADMIN_ROLE();

        timeLock.grantRole(proposerRole, address(governor));
        timeLock.grantRole(executorRole, address(0));
        timeLock.revokeRole(adminRole, USER);
        vm.stopPrank();

        box = new Box();
        box.transferOwnership(address(timeLock));
    }

    function testCantUpdateBoxWithoutGovernance() public {
        vm.expectRevert();
        box.store(1);
    }

    function testUpdateBoxWithVoteAndExecute() public {
        uint256 valueToSetInBox = 10;
        // 1  propose
        // 2. vote
        // 3. queue
        // 4. Execute
        string memory description = "change the number to 10 in box";
        bytes memory callHashFunction = abi.encodeWithSignature("store(uint256)", valueToSetInBox);
        calldatas.push(callHashFunction);
        targets.push(address(box));
        values.push(0);

        // vm.prank(USER);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);
        console.log("proposalId", proposalId);

        console.log("state --", uint256(governor.state(proposalId)));
        vm.roll(governor.proposalSnapshot(proposalId) + VOTING_DELAY);

        console.log("state after--", uint256(governor.state(proposalId)));

        uint8 voteFor = uint8(GovernorCountingSimple.VoteType.For); // voting in favor
        string memory reason = "doing the voting";

        vm.prank(USER);
        governor.castVoteWithReason(proposalId, voteFor, reason);

        vm.roll(block.number + VOTING_PERIOD + 1);
        console.log("state before queue--", uint256(governor.state(proposalId)));

        bytes32 descHash = keccak256(abi.encodePacked(description));
        governor.queue(targets, values, calldatas, descHash);
        console.log("state after queue--", uint256(governor.state(proposalId)));

        vm.warp(block.timestamp + MIN_DELAY + 1);
        vm.roll(block.number + MIN_DELAY + 1);
        governor.execute(targets, values, calldatas, descHash);

        assert(box.getNumber() == valueToSetInBox);
    }
}
