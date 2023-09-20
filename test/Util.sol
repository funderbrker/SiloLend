// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@forge-std/Test.sol";

import {C} from "src/C.sol";

contract HandlerUtils is Test {
    mapping(bytes32 => uint256) public calls;
    address[] public actors;
    address internal currentActor;

    constructor() {}

    modifier createActor() {
        vm.assume(msg.sender != address(0));
        currentActor = msg.sender;
        actors.push(msg.sender);
        _;
    }

    modifier useActor(uint256 actorIdxSeed) {
        currentActor = actors[bound(actorIdxSeed, 0, actors.length - 1)];
        _;
        currentActor = address(0);
    }

    modifier countCall(bytes32 key) {
        calls[key]++;
        _;
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        console.log("deposit", calls["deposit"]);
    }

    function actorsLength() external view returns (uint256) {
        return actors.length;
    }
}
