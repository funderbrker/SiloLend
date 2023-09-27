/**
 * SPDX-License-Identifier: MIT
 *
 */

pragma solidity 0.8.19;

import {C} from "src/C.sol";
import {ISiloFacet} from "src/interfaces/ISiloFacet.sol";

library LibBeanstalk {
    /// @notice Returns the deposit ID with Beanstalk stem in current season.
    function getCurrentDepositId(address token) internal view returns (uint256) {
        ISiloFacet silo_facet_ = ISiloFacet(C.BEANSTALK);
        return silo_facet_.getDepositId(token, silo_facet_.stemTipForToken(token));
    }

    function packAddressAndStem(address _address, int96 stem) internal pure returns (uint256) {
        // https://www.geeksforgeeks.org/solidity-conversions/
        // return uint256(_address) << 96 | uint96(stem);
        // address bytes on left, stem bytes on right
        return uint256((bytes32(bytes20(_address)) | bytes32(bytes12(uint96(stem))) >> 160));
    }

    /// @dev Copied from Beanstalk repo
    function unpackAddressAndStem(uint256 data) internal pure returns (address, int96) {
        return (address(uint160(data >> 96)), int96(int256(data)));
    }
}

// Running questions
// 1. If the seed/BDV of a token changes, will the IDs of existing deposits be retro changd via BIP?
