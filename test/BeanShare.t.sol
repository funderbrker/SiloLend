// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC1155} from "@solmate/tokens/ERC1155.sol";

import {C} from "src/C.sol";
import {BeanShare} from "src/BeanShare.sol";
import {LibBeanstalk} from "src/LibBeanstalk.sol";

import {IBeanstalkTest} from "test/helpers/IBeanstalkTest.sol";
import {BeanShareHandler} from "test/helpers/BeanShareHandler.sol";

contract BeanShareTest is Test {
    BeanShare beanShare;
    IBeanstalkTest beanstalk;
    uint256[] depositIds;
    uint256[] values;

    ERC1155 beanDeposits;

    constructor() {
        beanstalk = IBeanstalkTest(C.BEANSTALK);
        beanDeposits = ERC1155(C.BEAN_DEPOSIT);
    }

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18_208_878);

        beanShare = new BeanShare();
    }

    function _addSupply(address user, uint256 beanAmount) public {
        vm.prank(user);
        ERC20(C.BEAN).approve(address(beanShare), beanAmount);

        vm.prank(user);
        beanShare.addSupply(beanAmount);
    }

    function _addCollateral(address user, uint256 beanAmount) public {
        vm.prank(user);
        ERC20(C.BEAN).approve(address(beanstalk), beanAmount);

        vm.prank(user);
        (uint256 depositAmount,, int96 stem) = beanstalk.deposit(C.BEAN, beanAmount, 0);

        uint256 depositId = LibBeanstalk.packAddressAndStem(C.BEAN, stem);
        depositIds.push(depositId);
        values.push(depositAmount);

        vm.prank(user);
        beanstalk.approveDeposit(address(beanShare), C.BEAN, depositAmount);

        vm.prank(user);
        beanShare.addCollateral(depositIds, values);
    }

    function _clearDeposits() public {
        for (uint256 i; i < depositIds.length; i++) {
            depositIds.pop();
            values.pop();
        }
    }

    function test_AddRemoveSupply() public {
        address user = address(123);
        uint256 beanAmount = 1000e6;
        deal(C.BEAN, user, beanAmount, true);

        _addSupply(user, beanAmount);

        vm.prank(user);
        beanShare.removeSupply(beanAmount);
    }

    function test_AddRemoveCollateral() public {
        address user = address(123);

        uint256 beanAmount = 1000e6;
        deal(C.BEAN, user, beanAmount, true);

        _addCollateral(user, beanAmount);

        vm.prank(user);
        beanShare.removeCollateral(depositIds, values);
    }

    function test_AddRemoveBorrow() public {
        address supplier = address(1001);
        address borrower = address(1002);

        uint256 supplyAmount = 10_000e6;
        deal(C.BEAN, supplier, supplyAmount, true);
        _addSupply(supplier, supplyAmount);

        uint256 collateralAmount = 5000e6;
        deal(C.BEAN, borrower, collateralAmount, true);
        _addCollateral(borrower, collateralAmount);

        uint256 borrowAmount = 4000e6;
        vm.prank(borrower);
        beanShare.addBorrow(borrowAmount);

        vm.prank(borrower);
        ERC20(C.BEAN).approve(address(beanShare), borrowAmount);
        vm.prank(borrower);
        beanShare.removeBorrow(borrowAmount);
    }

    function test_DepositIdHandling(address addr, int96 stem) public pure {
        uint256 id = LibBeanstalk.packAddressAndStem(addr, stem);
        (address unpackedAddr, int96 unpackedStem) = LibBeanstalk.unpackAddressAndStem(id);
        require(addr == unpackedAddr, "Bad addr packing");
        require(stem == unpackedStem, "Bad stem packing");
    }
}

contract BeanShareInvariant is Test {
    BeanShareHandler public handler;

    function setUp() public {
        vm.recordLogs();
        vm.createSelectFork(vm.rpcUrl("mainnet"), 18_208_878);

        // Default invariant targets deployed here.
        handler = new BeanShareHandler();
        targetContract(address(handler));
    }

    function invariant_UserSupplyBalanceGEQSupplyIn() public view {
        uint256 netUserSupplyIn;
        for (uint256 i; i < handler.actorCount(); i++) {
            address user = handler.actors(i);
            netUserSupplyIn =
                handler.ghost_UserAddSupply(user) - handler.ghost_UserRemoveSupply(user);
            require(handler.beanShare().getUserSupplyBalance(user) >= netUserSupplyIn);
        }
    }

    function invariant_CallSummary() public view {
        handler.callSummary();
    }

    // NOTE should fail sometimes when loans forced terminated
    // function invariant_SupplyGEQBorrow() {}
}
