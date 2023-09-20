// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";

import {C} from "src/C.sol";
import {BeanShare} from "src/BeanShare.sol";

contract BeanShareTest is Test {
    BeanShare beanShare;

    constructor() {}

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 17_190_000);

        beanShare = new BeanShare();
    }

    function test_AddSupply() public {
        address user = address(123);

        deal(C.BEAN, user, 1000e6, true);

        vm.prank(user);
        ERC20(C.BEAN).approve(address(beanShare), 10e6);

        vm.prank(user);
        beanShare.addSupply(10e6);

        vm.prank(user);
        beanShare.removeSupply(10e6);
    }
}
