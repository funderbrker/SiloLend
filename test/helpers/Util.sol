// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/console.sol";
import {CommonBase} from "forge-std/Base.sol";

contract AddressBook is CommonBase {
    address[] public actors;
    mapping(address => bool) public saved;

    modifier createOrUseActor() {
        add(msg.sender);
        vm.startPrank(msg.sender);
        _;
        vm.stopPrank();
    }

    modifier useActor(uint256 actorIndexSeed) {
        vm.startPrank(rand(actorIndexSeed));
        _;
        vm.stopPrank();
    }

    function actorCount() public view returns (uint256) {
        return actors.length;
    }

    function add(address addr) internal {
        vm.assume(addr != address(0));
        if (!saved[addr]) {
            actors.push(addr);
            saved[addr] = true;
        }
    }

    function contains(address addr) internal view returns (bool) {
        return saved[addr];
    }

    function rand(uint256 seed) internal view returns (address) {
        if (actors.length > 0) {
            return actors[seed % actors.length];
        } else {
            return address(123_456_789);
        }
    }

    function forEach(function(address) external func) internal {
        for (uint256 i; i < actors.length; ++i) {
            func(actors[i]);
        }
    }
}

contract callCounter {
    mapping(bytes32 => uint256) public counts;
    bytes32[] calls;

    modifier countCall(bytes32 call) {
        if (counts[call] == 0) {
            calls.push(call);
        }
        counts[call]++;
        _;
    }

    function callSummary() external view {
        console.log("Call summary:");
        console.log("-------------------");
        for (uint256 i; i < calls.length; i++) {
            console.logBytes32(calls[i]);
            console.log("    ", counts[calls[i]]);
        }
    }
}
