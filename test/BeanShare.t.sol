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

        (uint256[] memory ids, uint256[] memory values) = _addCollateral(user, beanAmount);

        vm.prank(user);
        beanShare.removeCollateral(ids, values);
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

    function test_DepositIdHandling(address addr, int96 stem) public {
        uint256 id = LibBeanstalk.packAddressAndStem(addr, stem);
        (address unpackedAddr, int96 unpackedStem) = LibBeanstalk.unpackAddressAndStem(id);
        assertEq(addr, unpackedAddr, "Bad addr packing");
        assertEq(stem, unpackedStem, "Bad stem packing");
    }

    function test_BadDebt(uint256 baseAmount, uint16 holdBlocks) public {
        baseAmount = bound(baseAmount, 1, type(uint64).max);
        // holdBlocks = uint16(bound(holdBlocks, 1, type(uint16).max));
        address supplier = address(1001);
        address borrower = address(1002);
        address terminator = address(1003);

        uint256 supplyAmount = baseAmount;
        deal(C.BEAN, supplier, supplyAmount, true);
        _addSupply(supplier, supplyAmount);

        uint256 collateralAmount = baseAmount;
        deal(C.BEAN, borrower, collateralAmount, true);
        (uint256[] memory ids,) = _addCollateral(borrower, collateralAmount);

        uint256 borrowAmount = collateralAmount * 4 / 5;
        vm.prank(borrower);
        beanShare.addBorrow(borrowAmount);

        if (borrowAmount > 0) {
            // Time passed. Borrower amount owed increases. Supplier entitlement increases.
            uint256 maxDebt_ = (beanShare.MCR() * collateralAmount) / C.FACTOR;
            uint256 buffer = maxDebt_ - borrowAmount;
            uint256 secsUntilTerminable =
                (buffer + 1) * C.FACTOR / borrowAmount / beanShare.getBorrowRate(C.FACTOR);
            _incrementBlockAndTime(secsUntilTerminable / 10);
            beanstalk.balanceOf(address(beanShare), ids[0]);
            assertGt(beanShare.getUserSupplyBalance(supplier), supplyAmount, "Supply no increase");
            assertGt(beanShare.getUserBorrowBalance(borrower), borrowAmount, "Borrow no increase");
            beanShare.getUserCollateralBalance(borrower);

            // In worst case of bad debt exceeding reserves, terminate caller must pick up tab. Prepare.
            deal(C.BEAN, terminator, borrowAmount * 2, true);
            vm.prank(terminator);
            ERC20(C.BEAN).approve(address(beanShare), borrowAmount * 2);

            vm.prank(terminator);
            beanShare.terminate(borrower, ids);
        }

        // No bad debt.
        assertGe(beanShare.getSupplyBalance(), beanShare.getBorrowBalance(), "Supply < Borrow");
        // TODO double check sanity of relation between these 3 variables
        assertGe(
            beanShare.getSupplyBalance() + beanShare.getReserves(),
            beanShare.getBorrowBalance(),
            "Supply + Reserves < Borrow"
        );
    }

    function _addSupply(address user, uint256 beanAmount) private {
        vm.prank(user);
        ERC20(C.BEAN).approve(address(beanShare), beanAmount);

        vm.prank(user);
        beanShare.addSupply(beanAmount);
    }

    function _addCollateral(
        address user,
        uint256 beanAmount
    ) private returns (uint256[] memory ids, uint256[] memory values) {
        vm.prank(user);
        ERC20(C.BEAN).approve(address(beanstalk), beanAmount);

        vm.prank(user);
        // Cannot deposit amount == 0.
        (uint256 depositAmount,, int96 stem) = beanstalk.deposit(C.BEAN, beanAmount, 0);

        ids = new uint256[](1);
        values = new uint256[](1);
        ids[0] = LibBeanstalk.packAddressAndStem(C.BEAN, stem);
        values[0] = depositAmount;

        vm.prank(user);
        beanstalk.approveDeposit(address(beanShare), C.BEAN, depositAmount);

        vm.prank(user);
        beanShare.addCollateral(ids, values);
    }

    function _incrementBlockAndTime(uint256 nBlocks) private {
        console.log("Incrementing blocks and time by ", nBlocks);
        vm.warp(block.timestamp + nBlocks * 12);
        vm.roll(block.number + nBlocks);
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

    function invariant_UserBalancesCorrect() public {
        uint256 totalSupplyBalance;
        uint256 totalCollateralBalance;
        uint256 totalBorrowBalance;
        uint256 userSupplyBalance;
        uint256 userCollateralBalance;
        uint256 userBorrowBalance;

        for (uint256 i; i < handler.actorCount(); i++) {
            userSupplyBalance = userCollateralBalance = userBorrowBalance = 0;
            address user = handler.actors(i);
            userSupplyBalance =
                handler.ghost_UserAddSupply(user) - handler.ghost_UserRemoveSupply(user);
            assertEq(
                handler.beanShare().getUserSupplyBalance(user),
                userSupplyBalance,
                "userSupplyBalance incorrect"
            );
            userCollateralBalance =
                handler.ghost_UserAddCollateral(user) - handler.ghost_UserRemoveCollateral(user);
            assertEq(
                handler.beanShare().getUserCollateralBalance(user),
                userCollateralBalance,
                "userCollateralBalance incorrect"
            );
            userBorrowBalance =
                handler.ghost_UserAddBorrow(user) - handler.ghost_UserRemoveBorrow(user);
            assertEq(
                handler.beanShare().getUserBorrowBalance(user),
                userBorrowBalance,
                "userBorrowBalance incorrect"
            );

            // Borrow should always be <= collateral * MCR
            assertLe(
                userBorrowBalance, userCollateralBalance * handler.beanShare().MCR() / C.FACTOR
            );

            // Increment totals.
            totalSupplyBalance += userSupplyBalance;
            totalCollateralBalance += userCollateralBalance;
            totalBorrowBalance += userBorrowBalance;
        }

        // Verify ghost values are in sync.
        assertEq(
            totalSupplyBalance,
            handler.ghost_AddSupply() - handler.ghost_RemoveSupply(),
            "Bad test data: Supply"
        );
        assertEq(
            totalCollateralBalance,
            handler.ghost_AddCollateral() - handler.ghost_RemoveCollateral(),
            "Bad test data: Collateral"
        );
        assertEq(
            totalBorrowBalance,
            handler.ghost_AddBorrow() - handler.ghost_RemoveBorrow(),
            "Bad test data: Borrow"
        );

        assertEq(
            totalSupplyBalance,
            handler.beanShare().getSupplyBalance(),
            "Total supply balance incorrect"
        );
        assertEq(
            totalBorrowBalance,
            handler.beanShare().getBorrowBalance(),
            "Total borrow balance incorrect"
        );
    }

    function invariant_NotOverBorrowed() public {
        assertGe(
            handler.beanShare().getSupplyBalance(),
            handler.beanShare().getBorrowBalance(),
            "Total borrows exceed supply"
        );

        uint256 totalCollateralBalance =
            handler.ghost_AddCollateral() - handler.ghost_RemoveCollateral();
        assertLe(
            handler.beanShare().getBorrowBalance(),
            totalCollateralBalance * handler.beanShare().MCR() / C.FACTOR
        );
    }

    function invariant_CostsSync() public {
        uint256 supplierProfit = handler.beanShare().getSupplyBalance()
            - (handler.ghost_AddSupply() - handler.ghost_RemoveSupply());
        uint256 borrowerCost = handler.beanShare().getBorrowBalance()
            - (handler.ghost_AddBorrow() - handler.ghost_RemoveBorrow());
        assertEq(
            supplierProfit - borrowerCost,
            handler.beanShare().getReserves(),
            "Supply/Borrow/Reserves unbalanced"
        );
    }

    // // Remove all user positions. Ensure balances are correct.
    // function invariant_SuccessfulWindDown() public view {}

    // function invariant_CallSummary() public view {
    //     handler.callSummary();
    // }

    // NOTE should fail sometimes when loans forced terminated
    // function invariant_SupplyGEQBorrow() {}
}
