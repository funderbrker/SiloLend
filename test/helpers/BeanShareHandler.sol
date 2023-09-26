// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@forge-std/Test.sol";
import "@forge-std/console.sol";

import {ERC20} from "@solmate/tokens/ERC20.sol";
import {ERC1155} from "@solmate/tokens/ERC1155.sol";

import {C} from "src/C.sol";
import {BeanShare} from "src/BeanShare.sol";
import {AddressBook, callCounter} from "test/helpers/Util.sol";
import {LibBeanstalk} from "src/LibBeanstalk.sol";
import {IBeanstalkTest} from "test/helpers/IBeanstalkTest.sol";

/*
 * This handler is designed to be tested with invariants and fail_on_revert = true.
 * Parameter bounding is done using the contract state, to avoid uninteresting reverts.
 * Invariants should check all state (possibly against ghost values) and fail if anything is
 * invalid.
 */

/// @notice Handler to assist with invariant testing.
/// @dev Should never revert.
contract BeanShareHandler is Test, AddressBook, callCounter {
    BeanShare public beanShare;
    IBeanstalkTest beanstalk;
    ERC1155 beanDeposits;

    // Ghost variables.
    mapping(address => uint256) public ghost_UserAddSupply;
    mapping(address => uint256) public ghost_UserRemoveSupply;
    mapping(address => uint256) public ghost_UserAddCollateral;
    mapping(address => uint256) public ghost_UserRemoveCollateral;
    mapping(address => uint256) public ghost_UserAddBorrow;
    mapping(address => uint256) public ghost_UserRemoveBorrow;

    mapping(address => uint256[]) ghost_UserDeposits;
    mapping(address => mapping(uint256 => uint256)) ghost_UserDepositAmount;

    constructor() {
        beanShare = new BeanShare();
        beanstalk = IBeanstalkTest(C.BEANSTALK);
        beanDeposits = ERC1155(C.BEAN_DEPOSIT);
    }

    function addSupply(uint256 amount) external createOrUseActor countCall("addSupply") {
        amount = bound(amount, 0, type(uint128).max);
        deal(C.BEAN, msg.sender, amount, true); // avoid revert
        ERC20(C.BEAN).approve(address(beanShare), amount);

        ghost_UserAddSupply[msg.sender] += amount;
        beanShare.addSupply(amount);
    }

    function removeSupply(
        uint256 amount,
        uint256 actorSeed
    ) external useActor(actorSeed) countCall("removeSupply") {
        amount = bound(amount, 0, beanShare.getUserSupplyBalance(msg.sender)); // avoid revert

        ghost_UserRemoveSupply[msg.sender] += amount;
        beanShare.removeSupply(amount);
    }

    function addCollateral(uint256 value) external createOrUseActor countCall("addCollateral") {
        uint256[] memory ids = new uint256[](1);
        uint256[] memory values = new uint256[](1);
        values[0] = bound(value, 1, type(uint64).max);
        deal(C.BEAN, msg.sender, values[0], true);
        ERC20(C.BEAN).approve(address(beanstalk), values[0]);
        (uint256 depositAmount,, int96 stem) = beanstalk.deposit(C.BEAN, values[0], 0);
        require(depositAmount == values[0], "Unexpected depositAmount");
        ids[0] = LibBeanstalk.packAddressAndStem(C.BEAN, stem);
        beanstalk.approveDeposit(address(beanShare), C.BEAN, values[0]);
        beanShare.addCollateral(ids, values);
    }

    function removeCollateral(
        uint256 userDepositIndex,
        uint256 actorSeed
    ) external useActor(actorSeed) countCall("removeCollateral") {
        if (ghost_UserDeposits[msg.sender].length == 0) return;
        vm.assume(ghost_UserAddCollateral[msg.sender] - ghost_UserRemoveCollateral[msg.sender] > 0);
        userDepositIndex = bound(userDepositIndex, 0, ghost_UserDeposits[msg.sender].length);
        uint256 id = ghost_UserDeposits[msg.sender][userDepositIndex];
        uint256 amount = ghost_UserDepositAmount[msg.sender][id];
        ghost_UserDepositAmount[msg.sender][id] = 0;

        uint256[] memory ids = new uint256[](1);
        ids[0] = id;
        uint256[] memory values = new uint256[](1);
        values[0] = amount;
        beanShare.removeCollateral(ids, values);
    }

    function addBorrow(
        uint256 amount,
        uint256 actorSeed
    ) external useActor(actorSeed) countCall("addBorrow") {
        uint256 borrowCapacity =
            beanShare.getUserCollateralBalance(msg.sender) * beanShare.MCR() / C.FACTOR;
        amount = bound(amount, 0, borrowCapacity - beanShare.getUserBorrowBalance(msg.sender));
        beanShare.addBorrow(amount);
    }

    function removeBorrow(
        uint256 amount,
        uint256 actorSeed
    ) external useActor(actorSeed) countCall("removeBorrow") {
        amount = bound(amount, 0, beanShare.getUserBorrowBalance(msg.sender));
        beanShare.removeBorrow(amount);
    }

    // function terminate(
    //     address borrower,
    //     uint256[] calldata depositIds
    // ) external prankCurrentActor countCall("terminate") {
    //     beanShare.terminate(borrower, depositIds);
    // }

    // function withdrawReserves(address to, uint256 amount) external prankCurrentActor countCall("withdrawReserves") {
    //     beanShare.withdrawReserves(to, amount);
    // }

    // NOTE foundry invariant testing not compatible with time/block changes. Kind of a big miss...
    // function incrementBlockAndTime(uint8 nBlocks) public {
    //     vm.warp(block.timestamp + nBlocks * 12);
    //     vm.roll(block.number + nBlocks);
    // }
}
