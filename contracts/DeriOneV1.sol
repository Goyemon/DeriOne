pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "./interfaces/IETHPriceOracle.sol";
import "./interfaces/IHegicETHOptionV888.sol";
import "./interfaces/IHegicETHPoolV888.sol";
import "./interfaces/IOpynExchangeV1.sol";
import "./interfaces/IOpynOptionsFactoryV1.sol";
import "./interfaces/IOpynOTokenV1.sol";
import "./interfaces/IUniswapFactoryV1.sol";
import "./libraries/Math.sol";

/// @author tai
/// @title A contract for getting the cheapest options price
/// @notice For now, this contract gets the cheapest ETH/WETH put options price from Opyn and Hegic
/// @dev can i put a contract instance in struct?
contract DeriOneV1 is Ownable {
    using SafeMath for uint256;

    IETHPriceOracle private ETHPriceOracleInstance;
    IHegicETHOptionV888 private HegicETHOptionV888Instance;
    IHegicETHPoolV888 private HegicETHPoolV888Instance;
    IOpynExchangeV1 private OpynExchangeV1Instance;
    IOpynOptionsFactoryV1 private OpynOptionsFactoryV1Instance;
    IOpynOTokenV1[] private oTokenV1InstanceList;
    IOpynOTokenV1[] private WETHPutOptionOTokenV1InstanceList;
    IOpynOTokenV1[] private filteredWETHPutOptionOTokenV1InstanceList;
    IUniswapFactoryV1 private UniswapFactoryV1Instance;

    address constant USDCTokenAddress =
        0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WETHTokenAddress =
        0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address[] private oTokenAddressList;

    IHegicETHOptionV888.OptionType constant putOptionType =
        IHegicETHOptionV888.OptionType.Put;
    IHegicETHOptionV888.OptionType constant callOptionType =
        IHegicETHOptionV888.OptionType.Call;

    struct TheCheapestETHPutOptionInHegicV888 {
        uint256 expiry;
        uint256 strike;
        uint256 premium;
    }
    TheCheapestETHPutOptionInHegicV888 theCheapestETHPutOptionInHegicV888;

    struct WETHPutOptionOTokensV1 {
        address oTokenAddress;
        uint256 expiry;
        uint256 strike;
        uint256 premium;
    }
    WETHPutOptionOTokensV1[] WETHPutOptionOTokenListV1;
    WETHPutOptionOTokensV1[] filteredWETHPutOptionOTokenListV1;

    struct TheCheapestWETHPutOptionInOpynV1 {
        address oTokenAddress;
        uint256 expiry;
        uint256 strike;
        uint256 premium;
    }
    TheCheapestWETHPutOptionInOpynV1 theCheapestWETHPutOptionInOpynV1;

    enum Protocol {OpynV1, HegicV888}
    struct TheCheapestETHPutOption {
        Protocol protocol;
        address oTokenAddress;
        address paymentTokenAddress;
        uint256 expiry;
        uint256 strike;
        uint256 premium;
        uint256 amount;
    }
    TheCheapestETHPutOption theCheapestETHPutOption;

    event NewETHPriceOracleAddressRegistered(address ETHPriceOracleAddress);
    event NewHegicETHOptionV888AddressRegistered(
        address hegicETHOptionV888Address
    );
    event NewHegicETHPoolV888AddressRegistered(address hegicETHPoolV888Address);
    event NewOpynExchangeV1AddressRegistered(address opynExchangeV1Address);
    event NewOpynOptionsFactoryV1AddressRegistered(
        address opynOptionsFactoryV1Address
    );
    event NewOpynOTokenV1AddressRegistered(address opynOTokenV1Address);
    event NewOpynWETHPutOptionOTokenV1AddressRegistered(
        address opynWETHPutOptionOTokenV1Address
    );
    event NewUniswapFactoryV1AddressRegistered(address uniswapFactoryV1Address);
    event NotWETHPutOptionsOToken(address oTokenAddress);
    event NewOptionBought();

    constructor(
        address _ETHPriceOracleAddress,
        address _hegicETHOptionV888Address,
        address _hegicETHPoolV888Address,
        address _opynExchangeV1Address,
        address _opynOptionsFactoryV1Address,
        address _uniswapFactoryV1Address
    ) public {
        instantiateETHPriceOracle(_ETHPriceOracleAddress);
        instantiateHegicETHOptionV888(_hegicETHOptionV888Address);
        instantiateHegicETHPoolV888(_hegicETHPoolV888Address);
        instantiateOpynExchangeV1(_opynExchangeV1Address);
        instantiateOpynOptionsFactoryV1(_opynOptionsFactoryV1Address);
        instantiateUniswapFactoryV1(_uniswapFactoryV1Address);
    }

    /// @notice instantiate the ETHPriceOracle contract
    /// @param _ETHPriceOracleAddress ETHPriceOracleAddress
    function instantiateETHPriceOracle(address _ETHPriceOracleAddress)
        public
        onlyOwner
    {
        ETHPriceOracleInstance = IETHPriceOracle(_ETHPriceOracleAddress);
        emit NewETHPriceOracleAddressRegistered(_ETHPriceOracleAddress);
    }

    /// @notice instantiate the HegicETHOptionV888 contract
    /// @param _hegicETHOptionV888Address HegicETHOptionV888Address
    function instantiateHegicETHOptionV888(address _hegicETHOptionV888Address)
        public
        onlyOwner
    {
        HegicETHOptionV888Instance = IHegicETHOptionV888(
            _hegicETHOptionV888Address
        );
        emit NewHegicETHOptionV888AddressRegistered(_hegicETHOptionV888Address);
    }

    /// @notice instantiate the HegicETHPoolV888 contract
    /// @param _hegicETHPoolV888Address HegicETHPoolV888Address
    function instantiateHegicETHPoolV888(address _hegicETHPoolV888Address)
        public
        onlyOwner
    {
        HegicETHPoolV888Instance = IHegicETHPoolV888(_hegicETHPoolV888Address);
        emit NewHegicETHPoolV888AddressRegistered(_hegicETHPoolV888Address);
    }

    /// @notice instantiate the OpynExchangeV1 contract
    /// @param _opynExchangeV1Address OpynExchangeV1Address
    function instantiateOpynExchangeV1(address _opynExchangeV1Address)
        public
        onlyOwner
    {
        OpynExchangeV1Instance = IOpynExchangeV1(_opynExchangeV1Address);
        emit NewOpynExchangeV1AddressRegistered(_opynExchangeV1Address);
    }

    /// @notice instantiate the OpynOptionsFactoryV1 contract
    /// @param _opynOptionsFactoryV1Address OpynOptionsFactoryV1Address
    function instantiateOpynOptionsFactoryV1(
        address _opynOptionsFactoryV1Address
    ) public onlyOwner {
        OpynOptionsFactoryV1Instance = IOpynOptionsFactoryV1(
            _opynOptionsFactoryV1Address
        );
        emit NewOpynOptionsFactoryV1AddressRegistered(
            _opynOptionsFactoryV1Address
        );
    }

    /// @notice instantiate the UniswapFactoryV1 contract
    /// @param _uniswapFactoryV1Address UniswapFactoryV1Address
    function instantiateUniswapFactoryV1(address _uniswapFactoryV1Address)
        public
        onlyOwner
    {
        UniswapFactoryV1Instance = IUniswapFactoryV1(_uniswapFactoryV1Address);
        emit NewUniswapFactoryV1AddressRegistered(_uniswapFactoryV1Address);
    }

    /// @notice instantiate the OpynOTokenV1 contract
    /// @param _opynOTokenV1AddressList OpynOTokenV1Address
    function instantiateOpynOTokenV1(address[] memory _opynOTokenV1AddressList)
        private
    {
        for (uint256 i = 0; i < _opynOTokenV1AddressList.length; i++) {
            oTokenV1InstanceList.push(
                IOpynOTokenV1(_opynOTokenV1AddressList[i])
            );
            emit NewOpynOTokenV1AddressRegistered(_opynOTokenV1AddressList[i]);
        }
    }

    /// @notice get the implied volatility
    function _getHegicV888ImpliedVolatility() private returns (uint256) {
        uint256 impliedVolatilityRate =
            HegicETHOptionV888Instance.impliedVolRate();
        return impliedVolatilityRate;
    }

    /// @notice get the underlying asset price
    function _getHegicV888ETHPrice() private returns (uint256) {
        (, int256 latestPrice, , , ) = ETHPriceOracleInstance.latestRoundData();
        uint256 ETHPrice = uint256(latestPrice);
        return ETHPrice;
    }

    /// @notice check if there is enough liquidity in Hegic pool
    /// @param optionSizeInETH the size of an option to buy in ETH
    function _hasEnoughETHLiquidityInHegicV888(uint256 optionSizeInETH)
        private
        returns (bool)
    {
        uint256 maxOptionSize =
            HegicETHPoolV888Instance.totalBalance().mul(8).div(10) -
                (HegicETHPoolV888Instance.totalBalance() -
                    HegicETHPoolV888Instance.lockedAmount());
        if (maxOptionSize > optionSizeInETH) {
            return true;
        } else if (maxOptionSize <= optionSizeInETH) {
            return false;
        }
    }

    /// @notice calculate the premium and get the cheapest ETH put option in Hegic v888
    /// @param minExpiry minimum expiration date
    /// @param minStrike minimum strike price
    /// @dev does minExpiry and minStrike always give the cheapest premium? why? is this true?
    function _getTheCheapestETHPutOptionInHegicV888(
        uint256 minExpiry,
        uint256 minStrike
    ) private {
        require(
            _hasEnoughETHLiquidityInHegicV888(theCheapestETHPutOption.amount) ==
                true,
            "your size is too big for liquidity in the Hegic V888"
        );
        uint256 impliedVolatility = _getHegicV888ImpliedVolatility();
        uint256 ETHPrice = _getHegicV888ETHPrice();
        uint256 minimumPremiumToPayInETH =
            Math._sqrt(minExpiry).mul(impliedVolatility).mul(
                minStrike.div(ETHPrice)
            );
        theCheapestETHPutOptionInHegicV888 = TheCheapestETHPutOptionInHegicV888(
            minimumPremiumToPayInETH,
            minExpiry,
            minStrike
        );
    }

    /// @notice get the list of WETH put option oToken addresses
    /// @dev in the Opyn V1, there are only put options and thus no need to filter a type
    /// @dev we don't use ETH put options because the Opyn V1 has vulnerability there
    function _getWETHPutOptionsOTokenAddressList() private {
        oTokenAddressList = OpynOptionsFactoryV1Instance.optionsContracts();
        instantiateOpynOTokenV1(oTokenAddressList);
        for (uint256 i = 0; i < oTokenV1InstanceList.length; i++) {
            if (
                oTokenV1InstanceList[i].underlying() == WETHTokenAddress &&
                oTokenV1InstanceList[i].expiry() > block.timestamp
            ) {
                WETHPutOptionOTokenV1InstanceList.push(oTokenV1InstanceList[i]);
                WETHPutOptionOTokenListV1[i].oTokenAddress = oTokenAddressList[
                    i
                ];
            } else {
                emit NotWETHPutOptionsOToken(oTokenAddressList[i]);
            }
        }
    }

    /// @notice get WETH Put Options that meet expiry and strike conditions
    /// @param minExpiry minimum expiration date
    /// @param maxExpiry maximum expiration date
    /// @param minStrike minimum strike price
    /// @param maxStrike maximum strike price
    function _filterWETHPutOptionsOTokenAddresses(
        uint256 minExpiry,
        uint256 maxExpiry,
        uint256 minStrike,
        uint256 maxStrike
    ) private {
        for (uint256 i = 0; i < WETHPutOptionOTokenV1InstanceList.length; i++) {
            if (
                minStrike <
                WETHPutOptionOTokenV1InstanceList[i].strikePrice() &&
                WETHPutOptionOTokenV1InstanceList[i].strikePrice() <
                maxStrike &&
                minExpiry < WETHPutOptionOTokenV1InstanceList[i].expiry() &&
                WETHPutOptionOTokenV1InstanceList[i].expiry() < maxExpiry
            ) {
                filteredWETHPutOptionOTokenV1InstanceList.push(
                    WETHPutOptionOTokenV1InstanceList[i]
                );
                filteredWETHPutOptionOTokenListV1[i]
                    .oTokenAddress = WETHPutOptionOTokenListV1[i].oTokenAddress;
            }
        }
    }

    /// @notice get the premium in the Opyn V1
    /// @param expiry expiration date
    /// @param strike strike price
    function _getOpynV1Premium(
        uint256 expiry,
        uint256 strike,
        uint256 oTokensToBuy
    ) private returns (uint256) {
        address oTokenAddress;
        for (
            uint256 i = 0;
            i < filteredWETHPutOptionOTokenV1InstanceList.length;
            i++
        ) {
            if (
                filteredWETHPutOptionOTokenV1InstanceList[i].expiry() ==
                expiry &&
                filteredWETHPutOptionOTokenV1InstanceList[i].strikePrice() ==
                strike
            ) {
                oTokenAddress = filteredWETHPutOptionOTokenListV1[i]
                    .oTokenAddress;
            } else {}
        }
        uint256 premiumToPayInETH =
            OpynExchangeV1Instance.premiumToPay(
                oTokenAddress,
                address(0),
                oTokensToBuy
            );
        return premiumToPayInETH;
    }

    function _constructFilteredWETHPutOptionOTokenListV1(uint256 optionSizeInETH)
        private
    {
        for (uint256 i = 0; i < filteredWETHPutOptionOTokenListV1.length; i++) {
            filteredWETHPutOptionOTokenListV1[i] = WETHPutOptionOTokensV1(
                filteredWETHPutOptionOTokenListV1[i].oTokenAddress,
                filteredWETHPutOptionOTokenV1InstanceList[i].expiry(),
                filteredWETHPutOptionOTokenV1InstanceList[i].strikePrice(),
                _getOpynV1Premium(
                    filteredWETHPutOptionOTokenV1InstanceList[i].expiry(),
                    filteredWETHPutOptionOTokenV1InstanceList[i].strikePrice(),
                    optionSizeInETH
                )
            );
        }
    }

    /// @notice check if there is enough liquidity in Opyn V1 pool
    /// @param optionSizeInETH the size of an option to buy in ETH
    /// @dev write a function for power operations. the SafeMath library doesn't support this yet.
    function _hasEnoughOTokenLiquidityInOpynV1(uint256 optionSizeInETH)
        private
        returns (bool)
    {
        address uniswapExchangeContractAddress =
            UniswapFactoryV1Instance.getExchange(
                theCheapestETHPutOption.oTokenAddress
            );
        IOpynOTokenV1 theCheapestOTokenV1Instance =
            IOpynOTokenV1(theCheapestETHPutOption.oTokenAddress);
        uint256 oTokenLiquidity =
            theCheapestOTokenV1Instance.balanceOf(
                uniswapExchangeContractAddress
            );
        (uint256 value, int32 exponent) =
            theCheapestOTokenV1Instance.oTokenExchangeRate();
        uint256 optionSizeInOToken =
            optionSizeInETH.mul(value.mul(10**exponent));
        if (optionSizeInOToken < oTokenLiquidity) {
            return true;
        } else {
            return false;
        }
    }

    function _getTheCheapestETHPutOptionInOpynV1(
        uint256 minExpiry,
        uint256 maxExpiry,
        uint256 minStrike,
        uint256 maxStrike,
        uint256 optionSizeInETH
    ) private {
        require(
            _hasEnoughOTokenLiquidityInOpynV1(theCheapestETHPutOption.amount) ==
                true,
            "your size is too big for this oToken liquidity in the Opyn V1"
        );
        _getWETHPutOptionsOTokenAddressList();
        _filterWETHPutOptionsOTokenAddresses(
            minExpiry,
            maxExpiry,
            minStrike,
            maxStrike
        );
        _constructFilteredWETHPutOptionOTokenListV1(optionSizeInETH);
        uint256 minimumPremium = filteredWETHPutOptionOTokenListV1[0].premium;
        for (uint256 i = 0; i < filteredWETHPutOptionOTokenListV1.length; i++) {
            if (
                filteredWETHPutOptionOTokenListV1[i].premium >
                filteredWETHPutOptionOTokenListV1[i + 1].premium
            ) {
                minimumPremium = filteredWETHPutOptionOTokenListV1[i + 1]
                    .premium;
            }
        }

        for (uint256 i = 0; i < filteredWETHPutOptionOTokenListV1.length; i++) {
            if (
                minimumPremium == filteredWETHPutOptionOTokenListV1[i].premium
            ) {
                theCheapestWETHPutOptionInOpynV1 = TheCheapestWETHPutOptionInOpynV1(
                    filteredWETHPutOptionOTokenListV1[i].oTokenAddress,
                    filteredWETHPutOptionOTokenListV1[i].expiry,
                    filteredWETHPutOptionOTokenListV1[i].strike,
                    minimumPremium
                );
            }
        }
    }

    /// @dev you need to think how premium is denominated. in opyn, it is USDC? in hegic, it's WETH?
    function getTheCheapestETHPutOption(
        uint256 minExpiry,
        uint256 maxExpiry,
        uint256 minStrike,
        uint256 maxStrike,
        uint256 optionSizeInETH
    ) internal {
        _getTheCheapestETHPutOptionInHegicV888(minExpiry, minStrike);
        _getTheCheapestETHPutOptionInOpynV1(
            minExpiry,
            maxExpiry,
            minStrike,
            maxStrike,
            optionSizeInETH
        );
        if (
            theCheapestETHPutOptionInHegicV888.premium <
            theCheapestWETHPutOptionInOpynV1.premium
        ) {
            theCheapestETHPutOption = TheCheapestETHPutOption(
                Protocol.OpynV1,
                theCheapestWETHPutOptionInOpynV1.oTokenAddress,
                address(0),
                theCheapestWETHPutOptionInOpynV1.expiry,
                theCheapestWETHPutOptionInOpynV1.strike,
                theCheapestWETHPutOptionInOpynV1.premium,
                0
            );
        } else if (
            theCheapestETHPutOptionInHegicV888.premium >
            theCheapestWETHPutOptionInOpynV1.premium
        ) {
            theCheapestETHPutOption = TheCheapestETHPutOption(
                Protocol.HegicV888,
                address(0),
                address(0),
                theCheapestETHPutOptionInHegicV888.expiry,
                theCheapestETHPutOptionInHegicV888.strike,
                theCheapestETHPutOptionInHegicV888.premium,
                0
            );
        } else {}
    }

    /// @notice creates a new option in Hegic V888
    /// @param expiry option period in seconds (1 days <= period <= 4 weeks)
    /// @param amount option amount
    /// @param strike strike price of the option
    function _buyETHPutOptionInHegicV888(
        uint256 expiry,
        uint256 amount,
        uint256 strike
    ) private {
        HegicETHOptionV888Instance.create(
            expiry,
            amount,
            strike,
            putOptionType
        );
    }

    /// @notice buy an ETH put option in Opyn V1
    /// @param receiver the account that will receive the oTokens
    /// @param oTokenAddress the address of the oToken that is being bought
    /// @param paymentTokenAddress the address of the token you are paying for oTokens with
    /// @param oTokensToBuy the number of oTokens to buy
    function _buyETHPutOptionInOpynV1(
        address receiver,
        address oTokenAddress,
        address paymentTokenAddress,
        uint256 oTokensToBuy
    ) private {
        OpynExchangeV1Instance.buyOTokens(
            receiver,
            oTokenAddress,
            paymentTokenAddress,
            oTokensToBuy
        );
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
            _buyETHPutOptionInHegicV888(
                theCheapestETHPutOption.expiry,
                theCheapestETHPutOption.amount,
                theCheapestETHPutOption.strike
            );
        } else if (theCheapestETHPutOption.protocol == Protocol.OpynV1) {
            _buyETHPutOptionInOpynV1(
                receiver,
                theCheapestETHPutOption.oTokenAddress,
                theCheapestETHPutOption.paymentTokenAddress,
                theCheapestETHPutOption.amount
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