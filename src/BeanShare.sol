// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

// import {ERC4626} from "@solmate/mixins/ERC4626.sol";
// import {IERC20} from "@openzeppelin/token/ERC20/IERC20.sol";
import {IERC1155, IERC165} from "@openzeppelin/token/ERC1155/IERC1155.sol";
import {IERC1155Receiver} from "@openzeppelin/token/ERC1155/IERC1155Receiver.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC20} from "@solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "@solmate/utils/SafeTransferLib.sol";

import {C} from "src/C.sol";
import {ISiloFacet} from "src/interfaces/ISiloFacet.sol";
import {LibBeanstalk} from "src/LibBeanstalk.sol";

contract BeanShare is Ownable, IERC1155Receiver {
    uint256 public totalSuppliedIndex;
    uint256 public totalBorrowedIndex;

    // Max collateralization ratio.
    uint256 public constant MCR = C.FACTOR;
    uint256 public constant TERM_ADVANCE = (C.FACTOR * 105) / 100; // 105%

    mapping(address => uint256) collateralBalance;
    mapping(address => mapping(uint256 => uint256)) deposits;

    // Relative ownerships of supply / debt.
    uint256 supplyIndex = C.FACTOR_INDEX; // arbitrary init
    mapping(address => uint256) userSupplyIndex;
    uint256 borrowIndex = C.FACTOR_INDEX; // arbitrary init
    mapping(address => uint256) userBorrowIndex;
    uint256 lastAccrualTime;

    constructor() {
        lastAccrualTime = block.timestamp;
    }

    /////////////////////// Utilization and Rates ///////////////////////

    function getSupplyRate(uint256 utilization) public view returns (uint256) {
        // TODO PLACEHOLDER
        return C.FACTOR / 20 / 365 / 24 / 60 / 60;
    }

    function getBorrowRate(uint256 utilization) public view returns (uint256) {
        // TODO PLACEHOLDER
        return C.FACTOR / 20 / 365 / 24 / 60 / 60;
    }

    function getUtilization() public view returns (uint256) {
        uint256 totalBorrowed_ = _getAmountBorrow(totalBorrowedIndex);
        uint256 totalSupplied_ = _getAmountSupply(totalSuppliedIndex);
        if (totalSupplied_ == 0) return 0;
        return (C.FACTOR * totalBorrowed_) / totalSupplied_;
    }

    /////////////////////// Accrual and Index Management ///////////////////////

    function _accrue() private {
        uint256 deltaTime_ = block.timestamp - lastAccrualTime;
        if (deltaTime_ > 0) {
            (supplyIndex, borrowIndex) = _getAccruedIndices(deltaTime_);
            lastAccrualTime = block.timestamp;
        }
    }

    function _getAccruedIndices(uint256 deltaTime_)
        internal
        view
        returns (uint256 supplyIndex_, uint256 borrowIndex_)
    {
        supplyIndex_ = supplyIndex;
        borrowIndex_ = borrowIndex;
        if (deltaTime_ > 0) {
            uint256 utilization = getUtilization();
            uint256 supplyRate = getSupplyRate(utilization);
            uint256 borrowRate = getBorrowRate(utilization);
            supplyIndex_ += (supplyIndex_ * supplyRate * deltaTime_) / C.FACTOR;
            borrowIndex_ += (borrowIndex_ * borrowRate * deltaTime_) / C.FACTOR;
        }
    }

    /////////////////////// Index Conversion ///////////////////////

    function _getIndexSupply(uint256 amount_) private view returns (uint256) {
        return (C.FACTOR_INDEX * amount_) / supplyIndex;
    }

    function _getAmountSupply(uint256 index_) private view returns (uint256) {
        return (index_ * supplyIndex) / C.FACTOR_INDEX;
    }

    function _getIndexBorrow(uint256 amount_) private view returns (uint256) {
        return (C.FACTOR_INDEX * amount_) / borrowIndex;
        // AUDIT rounding issue? logic seen in compound
        // return (C.FACTOR_INDEX * amount_ +=borrowIndex_ - 1) / borrowIndex_;
    }

    function _getAmountBorrow(uint256 index_) private view returns (uint256) {
        return (index_ * borrowIndex) / C.FACTOR_INDEX;
    }

    /////////////////////// Supply Add/Remove ///////////////////////

    function addSupply(uint256 amount) public {
        _accrue();
        _incrementSupply(msg.sender, amount);
        // deposit(assets, msg.sender);
        SafeTransferLib.safeTransferFrom(ERC20(C.BEAN), msg.sender, address(this), amount);
        _netSupplyInv();
    }

    function removeSupply(uint256 amount) public {
        _accrue();
        _decrementSupply(msg.sender, amount);
        // redeem(shares, msg.sender, msg.sender);
        SafeTransferLib.safeTransfer(ERC20(C.BEAN), msg.sender, amount);
        _netSupplyInv();
    }

    function _incrementSupply(address supplier, uint256 amount) private {
        uint256 userSupplyBalance_ = _getAmountSupply(userSupplyIndex[supplier]) + amount;
        uint256 userSupplyIndex_ = _getIndexSupply(userSupplyBalance_);
        totalSuppliedIndex += userSupplyIndex_ - userSupplyIndex[supplier];
        userSupplyIndex[supplier] = userSupplyIndex_;
    }

    function _decrementSupply(address supplier, uint256 amount) private {
        uint256 userSupplyBalance_ = _getAmountSupply(userSupplyIndex[supplier]) - amount;
        uint256 userSupplyIndex_ = _getIndexSupply(userSupplyBalance_);
        totalSuppliedIndex -= userSupplyIndex[supplier] - userSupplyIndex_;
        userSupplyIndex[supplier] = userSupplyIndex_;
    }

    /////////////////////// Take/Close Loan ///////////////////////

    function addBorrow(uint256 amount) external {
        _accrue();
        _incrementBorrow(msg.sender, amount);
        requireAcceptableDebt(msg.sender);
        SafeTransferLib.safeTransfer(ERC20(C.BEAN), msg.sender, amount);
    }

    function removeBorrow(uint256 amount) external {
        _accrue();
        _decrementBorrow(msg.sender, amount);
        requireAcceptableDebt(msg.sender);
        SafeTransferLib.safeTransferFrom(ERC20(C.BEAN), msg.sender, address(this), amount);
    }

    function _incrementBorrow(address borrower, uint256 amount) private {
        uint256 userBorrowBalance_ = _getAmountBorrow(userBorrowIndex[borrower]) + amount;
        uint256 userBorrowIndex_ = _getIndexBorrow(userBorrowBalance_);
        totalBorrowedIndex += userBorrowIndex_ - userBorrowIndex[borrower];
        userBorrowIndex[borrower] = userBorrowIndex_;
    }

    function _decrementBorrow(address borrower, uint256 amount) private {
        uint256 userBorrowBalance_ = _getAmountBorrow(userBorrowIndex[borrower]) - amount;
        uint256 userBorrowIndex_ = _getIndexBorrow(userBorrowBalance_);
        totalBorrowedIndex -= userBorrowIndex[borrower] - userBorrowIndex_;
        userBorrowIndex[borrower] = userBorrowIndex_;
    }

    /////////////////////// Collateral Add/Remove ///////////////////////

    function addCollateral(uint256[] calldata ids, uint256[] calldata values) public {
        for (uint256 i; i < ids.length; i++) {
            _incrementCollateral(msg.sender, ids[i], values[i]);
        }
        requireAcceptableDebt(msg.sender);
        IERC1155(C.BEAN_DEPOSIT).safeBatchTransferFrom(msg.sender, address(this), ids, values, "");
    }

    function removeCollateral(uint256[] calldata ids, uint256[] calldata values) public {
        for (uint256 i; i < ids.length; i++) {
            _decrementCollateral(msg.sender, ids[i], values[i]);
        }
        requireAcceptableDebt(msg.sender);
        IERC1155(C.BEAN_DEPOSIT).safeBatchTransferFrom(address(this), msg.sender, ids, values, "");
    }

    function _incrementCollateral(address from, uint256 id, uint256 amount) private {
        deposits[from][id] += amount;
        collateralBalance[from] += amount;
    }

    function _decrementCollateral(address from, uint256 id, uint256 amount) private {
        deposits[from][id] -= amount;
        collateralBalance[from] -= amount;
    }

    /////////////////////// Loan Termination ///////////////////////

    function terminate(address borrower, uint256[] calldata depositIds) external {
        _accrue();

        uint256 maxDebt_ = (MCR * collateralBalance[borrower]) / C.FACTOR;
        uint256 userDebt_ = _getAmountBorrow(userBorrowIndex[borrower]);
        uint256 terminationAmount_ = ((userDebt_ - maxDebt_) * TERM_ADVANCE) / C.FACTOR;
        _decrementBorrow(borrower, terminationAmount_);

        ISiloFacet siloFacet_ = ISiloFacet(C.SILO_FACET);
        for (uint256 i; i < depositIds.length; i++) {
            (, int96 stem_) = LibBeanstalk.unpackAddressAndStem(depositIds[i]);
            uint256 deposit_ = deposits[borrower][depositIds[i]];
            uint256 closeAmount_ = terminationAmount_ < deposit_ ? terminationAmount_ : deposit_;
            siloFacet_.withdrawDeposit(
                C.BEAN,
                stem_,
                closeAmount_,
                0 // LibTransfer.To mode == EXTERNAL
            );
            _decrementCollateral(borrower, depositIds[i], closeAmount_);
            terminationAmount_ -= closeAmount_;
        }
        require(terminationAmount_ == 0, "TerminateDepositsTooSmall");
        requireAcceptableDebt(borrower); // TODO unnecessary ?
    }

    /////////////////////// Reserves ///////////////////////

    function getReserves() public view returns (uint256) {
        (uint256 supplyIndex_, uint256 borrowIndex_) = _getAccruedIndices(block.timestamp - lastAccrualTime);
        uint256 balance = ERC20(C.BEAN).balanceOf(address(this));
        uint256 supplyAmount_ = _getAmountSupply(supplyIndex_);
        uint256 borrowAmount_ = _getAmountBorrow(borrowIndex_);
        uint256 supplyAmountExcess_ = supplyAmount_ - borrowAmount_;
        return balance <= supplyAmountExcess_ ? 0 : balance - supplyAmountExcess_;
    }

    function withdrawReserves(address to, uint256 amount) external onlyOwner {
        uint256 reserves = getReserves();
        require(amount <= reserves, "TooFewReserves");
        SafeTransferLib.safeTransfer(ERC20(C.BEAN), to, amount);
    }

    /////////////////////// Util ///////////////////////

    function requireAcceptableDebt(address borrower) private {
        uint256 userDebt = _getAmountBorrow(userBorrowIndex[borrower]);
        uint256 maxDebt = (MCR * collateralBalance[borrower]) / C.FACTOR;
        require(userDebt <= maxDebt, "TooMuchDebt");
    }

    function supportsInterface(bytes4 interfaceId) public pure override(IERC165) returns (bool) {
        return interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function onERC1155Received(address, address, uint256, uint256, bytes calldata) external returns (bytes4) {
        return 0xf23a6e61;
    }

    function onERC1155BatchReceived(address, address, uint256[] calldata, uint256[] calldata, bytes calldata)
        external
        returns (bytes4)
    {
        return 0xbc197c81;
    }

    /////////////////////// Invariants ///////////////////////

    function _netSupplyInv() internal view {
        uint256 supplyAmountExcess_ = _getAmountSupply(totalSuppliedIndex) - _getAmountBorrow(totalBorrowedIndex);
        // require(supplyAmountExcess_ >= 0, "SupplyTooLow");
        require(ERC20(C.BEAN).balanceOf(address(this)) >= supplyAmountExcess_, "BalanceTooLow");
    }

    /////////////////////// Testing ///////////////////////

    function echidna_NetSupplyInv() public returns (bool) {
        if (_getAmountSupply(totalSuppliedIndex) < _getAmountBorrow(totalBorrowedIndex)) return false;
        uint256 supplyAmountExcess_ = _getAmountSupply(totalSuppliedIndex) - _getAmountBorrow(totalBorrowedIndex);
        // if (ERC20(C.BEAN).balanceOf(address(this)) < supplyAmountExcess_) return false;
        return true;
    }

    function echidna_IDK() public returns (bool) {
        if (_getAmountSupply(totalSuppliedIndex) > 100000000000) return false;
        return true;
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

// TODO termination of borrower loan

// TODO enable and handle collateral planted deposit

// TODO supply as a deposit?
