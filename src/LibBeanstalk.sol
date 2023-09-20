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
        ISiloFacet silo_facet_ = ISiloFacet(C.SILO_FACET);
        return silo_facet_.getDepositId(token, silo_facet_.stemTipForToken(token));
    }

    /// @dev Copied from Beanstalk repo
    function unpackAddressAndStem(uint256 data) internal pure returns (address, int96) {
        return (address(uint160(data >> 96)), int96(int256(data)));
    }
}

// Running questions
// 1. If the seed/BDV of a token changes, will the IDs of existing deposits be retro changd via BIP?
