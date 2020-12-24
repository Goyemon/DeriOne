pragma solidity ^0.6.0;

import "./DeriOneV1HegicV888.sol";
import "./DeriOneV1OpynV1.sol";

/// @author tai
/// @title A contract for getting the cheapest options price
/// @notice For now, this contract gets the cheapest ETH/WETH put options price from Opyn and Hegic
/// @dev can i put a contract instance in struct?
contract DeriOneV1Main {
    enum Protocol {OpynV1, HegicV888}
    struct TheCheapestETHPutOption {
        Protocol protocol;
        address oTokenAddress;
        address paymentTokenAddress;
        uint256 expiry;
        uint256 strike;
        uint256 premium;
        uint256 optionSizeInETH;
    }
    TheCheapestETHPutOption theCheapestETHPutOption;

    event NewOptionBought();

    /// @dev you need to think how premium is denominated. in opyn, it is USDC? in hegic, it's WETH?
    function getTheCheapestETHPutOption(
        uint256 minExpiry,
        uint256 maxExpiry,
        uint256 minStrike,
        uint256 maxStrike,
        uint256 optionSizeInETH
    ) internal {
        DeriOneV1HegicV888.getTheCheapestETHPutOptionInHegicV888(
            minExpiry,
            minStrike,
            optionSizeInETH
        );
        DeriOneV1OpynV1.getTheCheapestETHPutOptionInOpynV1(
            minExpiry,
            maxExpiry,
            minStrike,
            maxStrike,
            optionSizeInETH
        );
        if (
            DeriOneV1HegicV888.theCheapestETHPutOptionInHegicV888.premium <
            DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.premium
        ) {
            theCheapestETHPutOption = TheCheapestETHPutOption(
                Protocol.OpynV1,
                DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.oTokenAddress,
                address(0),
                DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.expiry,
                DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.strike,
                DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.premium,
                0
            );
        } else if (
            DeriOneV1HegicV888.theCheapestETHPutOptionInHegicV888.premium >
            DeriOneV1OpynV1.theCheapestWETHPutOptionInOpynV1.premium
        ) {
            theCheapestETHPutOption = TheCheapestETHPutOption(
                Protocol.HegicV888,
                address(0),
                address(0),
                DeriOneV1HegicV888.theCheapestETHPutOptionInHegicV888.expiry,
                DeriOneV1HegicV888.theCheapestETHPutOptionInHegicV888.strike,
                DeriOneV1HegicV888.theCheapestETHPutOptionInHegicV888.premium,
                0
            );
        } else {}
    }

    function buyTheCheapestETHPutOption(
        uint256 minExpiry,
        uint256 maxExpiry,
        uint256 minStrike,
        uint256 maxStrike,
        uint256 optionSizeInETH,
        address receiver
    ) public {
        getTheCheapestETHPutOption(
            minExpiry,
            maxExpiry,
            minStrike,
            minStrike,
            optionSizeInETH
        );
        if (theCheapestETHPutOption.protocol == Protocol.HegicV888) {
            DeriOneV1HegicV888.buyETHPutOptionInHegicV888(
                theCheapestETHPutOption.expiry,
                theCheapestETHPutOption.optionSizeInETH,
                theCheapestETHPutOption.strike
            );
        } else if (theCheapestETHPutOption.protocol == Protocol.OpynV1) {
            DeriOneV1OpynV1.buyETHPutOptionInOpynV1(
                receiver,
                theCheapestETHPutOption.oTokenAddress,
                theCheapestETHPutOption.paymentTokenAddress,
                theCheapestETHPutOption.optionSizeInETH
            );
        } else {
            // there is no options
        }
    }
}

// watch new eth put options being created
// how do you compare options?
// what happens after our user buy? don't they want to exercise?
// we could make two functions: one gets some options and the other gets only one option
// console log solidity https://medium.com/nomic-labs-blog/better-solidity-debugging-console-log-is-finally-here-fc66c54f2c4a
// event, logx or
// truffle console log?
// make two functions. one that takes a range and the other that takes a fixed value. what to return when there is none?
// ask them: mazzi, gammahammer are both options traders irl. attm is a maths phd that prices options for living
// there are two functions: fixed expiry and strike function. in opyn, it is either nothing or exist. in hegic, it always returns only one.
// fixed values: in opyn, it is like that you can get options. in hegic, np.
// people perhaps want to buy the most liquid one so that they can make sure that they can sell it later?
// specify data location
// enforce state changes of state variables with a function by adding a storage keyword? i dont think so.
// adjust variable visibility
// think how functions call each other
// why say memory or calldata in a parameter?
// calldata and stack dont understand
// value type and reference type?
// stack and heap?
// think of a new way to structure your variables
// start function parameter variable names with an `underscore(_)` to differentiate them from global variables.
// add some function modifiers like view and pure?
// you cannot rely on abi to interface converter. it is not good. i made more than enough mistakes in the interfaces.
// explicitly state the data location for all variables of struct, array or mapping types (including function parameters)
// adjust visibility of variables. they should be all private by default i guess
// the way i handle otoken instances are wrong. this needs to be fixed.

// What to do with that strikePrice that returns two values. What do they do?
//    /* represents floting point numbers, where number = value * 10 ** exponent
//     i.e 0.1 = 10 * 10 ** -3 */
//     struct Number {
//         uint256 value;
//         int32 exponent;
//     }

// split this contract file into some files

// refer to uniswap factory contract to manage registry?

// perhaps hasLiquidity can be a modifier?

// import vs. inheritance

// rename to derionev1main and etc
