// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import {OracleLib, AggregatorV3Interface} from "./libraries/OracleLib.sol";
// The correct path for ReentrancyGuard in latest Openzeppelin contracts is
//"import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ARSXStableCoin} from "./ARSXStableCoin.sol";
import {IARSUSDTOracle} from "./interfaces/IARSUSDTOracle.sol";

/*
 * @title ARSXEngine
 * @author Rodrigo Garcia Kosinski
 * based on DSCEngine by Patrick Collins
 *
 * The system is designed to be as minimal as possible, and have the tokens maintain a 1 token == $1 ars peso at all times.
 * This is a stablecoin with the properties:
 * - Exogenously Collateralized
 * - Ars peso Pegged
 * - Algorithmically Stable
 *
 * It is similar to DAI if DAI had no governance, no fees, and was backed by only WETH.
 *
 * Our system should always be "overcollateralized". At no point, should the value of
 * all collateral < the $ backed value of all the ARSX.
 *
 * @notice This contract is the core of the Decentralized Stablecoin system. It handles all the logic
 * for minting and redeeming ARSX, as well as depositing and withdrawing collateral.
 * @notice This contract is based on the MakerDAO DSS system
 */
contract ARSXEngine is ReentrancyGuard {
    ///////////////////
    // Errors
    ///////////////////
    error ARSXEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
    error ARSXEngine__NeedsMoreThanZero();
    error ARSXEngine__TokenNotAllowed(address token);
    error ARSXEngine__TransferFailed();
    error ARSXEngine__BreaksHealthFactor(uint healthFactorValue);
    error ARSXEngine__MintFailed();
    error ARSXEngine__HealthFactorOk();
    error ARSXEngine__HealthFactorNotImproved();

    ///////////////////
    // Types
    ///////////////////
    using OracleLib for AggregatorV3Interface;

    ///////////////////
    // State Variables
    ///////////////////
    ARSXStableCoin private immutable i_arsx;

    uint private constant LIQUIDATION_THRESHOLD = 50; // This means you need to be 200% over-collateralized
    uint private constant LIQUIDATION_BONUS = 10; // This means you get assets at a 10% discount when liquidating
    uint private constant LIQUIDATION_PRECISION = 100;
    uint private constant MIN_HEALTH_FACTOR = 1e18;
    uint private constant PRECISION = 1e18;
    uint private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint private constant FEED_PRECISION = 1e8;
    uint private constant ARSX_ORACLE_PRECISION = 1e8;

    /// price feed for arsx
    IARSUSDTOracle private s_ARSXOracle;
    /// @dev Mapping of token address to price feed address
    mapping(address collateralToken => address priceFeed) private s_priceFeeds;
    /// @dev Amount of collateral deposited by user
    mapping(address user => mapping(address collateralToken => uint amount))
        private s_collateralDeposited;
    /// @dev Amount of ARSX minted by user
    mapping(address user => uint amount) private s_ARSXMinted;
    /// @dev If we know exactly how many tokens we have, we could make this immutable!
    address[] private s_collateralTokens;

    ///////////////////
    // Events
    ///////////////////
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint indexed amount
    );
    event CollateralRedeemed(
        address indexed redeemFrom,
        address indexed redeemTo,
        address token,
        uint amount
    ); // if
    // redeemFrom != redeemedTo, then it was liquidated

    ///////////////////
    // Modifiers
    ///////////////////
    modifier moreThanZero(uint amount) {
        if (amount == 0) {
            revert ARSXEngine__NeedsMoreThanZero();
        }
        _;
    }

    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert ARSXEngine__TokenNotAllowed(token);
        }
        _;
    }

    ///////////////////
    // Functions
    ///////////////////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address arsxAddress,
        address arsxOracleAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert ARSXEngine__TokenAddressesAndPriceFeedAddressesAmountsDontMatch();
        }
        for (uint i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_arsx = ARSXStableCoin(arsxAddress);
        s_ARSXOracle = IARSUSDTOracle(arsxOracleAddress);
    }

    ///////////////////
    // External Functions
    ///////////////////
    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     * @param amountArsxToMint: The amount of ARSX you want to mint
     * @notice This function will deposit your collateral and mint ARSX in one transaction
     */
    function depositCollateralAndMintArsx(
        address tokenCollateralAddress,
        uint amountCollateral,
        uint amountArsxToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintArsx(amountArsxToMint);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're withdrawing
     * @param amountCollateral: The amount of collateral you're withdrawing
     * @param amountArsxToBurn: The amount of Arsx you want to burn
     * @notice This function will withdraw your collateral and burn DSC in one transaction
     */
    function redeemCollateralForArsx(
        address tokenCollateralAddress,
        uint amountCollateral,
        uint amountArsxToBurn
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
    {
        _burnArsx(amountArsxToBurn, msg.sender, msg.sender);
        _redeemCollateral(
            tokenCollateralAddress,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're redeeming
     * @param amountCollateral: The amount of collateral you're redeeming
     * @notice This function will redeem your collateral.
     * @notice If you have ARSX minted, you will not be able to redeem until you burn your ARSX
     */
    function redeemCollateral(
        address tokenCollateralAddress,
        uint amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        _redeemCollateral(
            tokenCollateralAddress,
            amountCollateral,
            msg.sender,
            msg.sender
        );
        revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice careful! You'll burn your ARSX here! Make sure you want to do this...
     * @dev you might want to use this if you're nervous you might get liquidated and want to just burn
     * your ARSX but keep your collateral in.
     */
    function burnArsx(uint amount) external moreThanZero(amount) {
        _burnArsx(amount, msg.sender, msg.sender);
        revertIfHealthFactorIsBroken(msg.sender); // I don't think this would ever hit...
    }

    /*
     * @param collateral: The ERC20 token address of the collateral you're using to make the protocol solvent again.
     * This is collateral that you're going to take from the user who is insolvent.
     * In return, you have to burn your ARSX to pay off their debt, but you don't pay off your own.
     * @param user: The user who is insolvent. They have to have a _healthFactor below MIN_HEALTH_FACTOR
     * @param debtToCover: The amount of ARSX you want to burn to cover the user's debt.
     *
     * @notice: You can partially liquidate a user.
     * @notice: You will get a 10% LIQUIDATION_BONUS for taking the users funds.
    * @notice: This function working assumes that the protocol will be roughly 150% overcollateralized in order for this
    to work.
    * @notice: A known bug would be if the protocol was only 100% collateralized, we wouldn't be able to liquidate
    anyone.
     * For example, if the price of the collateral plummeted before anyone could be liquidated.
     */
    function liquidate(
        address collateral,
        address user,
        uint debtToCover //ej 1000 pesos
    )
        external
        isAllowedToken(collateral)
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert ARSXEngine__HealthFactorOk();
        }
        // If covering 100 usd of ARSX, we need to $100 of collateral
        uint tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateral,
            debtToCover
        );
        // And give them a 10% bonus
        // So we are giving the liquidator $110 of WETH for 100 ARSX
        // We should implement a feature to liquidate in the event the protocol is insolvent
        // And sweep extra amounts into a treasury
        uint bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        // Burn ARSX equal to debtToCover
        // Figure out how much collateral to recover based on how much burnt
        _redeemCollateral(
            collateral,
            tokenAmountFromDebtCovered + bonusCollateral,
            user,
            msg.sender
        );
        _burnArsx(debtToCover, user, msg.sender);

        uint endingUserHealthFactor = _healthFactor(user);
        // This conditional should never hit, but just in case
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert ARSXEngine__HealthFactorNotImproved();
        }
        revertIfHealthFactorIsBroken(msg.sender);
    }

    ///////////////////
    // Public Functions
    ///////////////////
    /*
     * @param amountArsxToMint: The amount of ARSX you want to mint
     * You can only mint ARSX if you have enough collateral
     */

    function mintArsx(
        uint amountArsxToMint
    ) public moreThanZero(amountArsxToMint) nonReentrant {
        s_ARSXMinted[msg.sender] += amountArsxToMint;
        revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_arsx.mint(msg.sender, amountArsxToMint);

        if (minted != true) {
            revert ARSXEngine__MintFailed();
        }
    }

    /*
     * @param tokenCollateralAddress: The ERC20 token address of the collateral you're depositing
     * @param amountCollateral: The amount of collateral you're depositing
     */
    function depositCollateral(
        address tokenCollateralAddress,
        uint amountCollateral
    )
        public
        moreThanZero(amountCollateral)
        nonReentrant
        isAllowedToken(tokenCollateralAddress)
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert ARSXEngine__TransferFailed();
        }
    }

    ///////////////////
    // Private Functions
    ///////////////////
    function _redeemCollateral(
        address tokenCollateralAddress,
        uint amountCollateral,
        address from,
        address to
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(
            from,
            to,
            tokenCollateralAddress,
            amountCollateral
        );
        bool success = IERC20(tokenCollateralAddress).transfer(
            to,
            amountCollateral
        );
        if (!success) {
            revert ARSXEngine__TransferFailed();
        }
    }

    function _burnArsx(
        uint amountArsxToBurn,
        address onBehalfOf,
        address arsxFrom
    ) private {
        s_ARSXMinted[onBehalfOf] -= amountArsxToBurn;

        bool success = i_arsx.transferFrom(
            arsxFrom,
            address(this),
            amountArsxToBurn
        );
        // This conditional is hypothetically unreachable
        if (!success) {
            revert ARSXEngine__TransferFailed();
        }
        i_arsx.burn(amountArsxToBurn);
    }

    //////////////////////////////
    // Private & Internal View & Pure Functions
    //////////////////////////////

    function _getAccountInformation(
        address user
    ) private view returns (uint totalArsxMinted, uint collateralValueInUsd) {
        totalArsxMinted = s_ARSXMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    function _healthFactor(address user) private view returns (uint) {
        (, uint collateralValueInUsd) = _getAccountInformation(user);

        (uint arsxPrice, , ) = s_ARSXOracle.latestData();
        uint totalArsxMintedInUsd = (s_ARSXMinted[user] * arsxPrice) /
            ARSX_ORACLE_PRECISION;
        return
            _calculateHealthFactor(totalArsxMintedInUsd, collateralValueInUsd);
    }

    function _getUsdValue(
        address token,
        uint amount
    ) private view returns (uint) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return ((uint(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function _calculateHealthFactor(
        uint totalArsxMintedInUsd,
        uint collateralValueInUsd
    ) internal pure returns (uint) {
        if (totalArsxMintedInUsd == 0) return type(uint).max;
        uint collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return
            (collateralAdjustedForThreshold * PRECISION) / totalArsxMintedInUsd;
    }

    function revertIfHealthFactorIsBroken(address user) internal view {
        uint userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert ARSXEngine__BreaksHealthFactor(userHealthFactor);
        }
    }

    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    // External & Public View & Pure Functions
    ////////////////////////////////////////////////////////////////////////////
    ////////////////////////////////////////////////////////////////////////////
    function calculateHealthFactor(
        uint totalArsxMintedInUsd,
        uint collateralValueInUsd
    ) external pure returns (uint) {
        return
            _calculateHealthFactor(totalArsxMintedInUsd, collateralValueInUsd);
    }

    function getAccountInformation(
        address user
    ) external view returns (uint totalArsxMinted, uint collateralValueInUsd) {
        return _getAccountInformation(user);
    }

    function getUsdValue(
        address token,
        uint amount // in WEI
    ) external view returns (uint) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(
        address user,
        address token
    ) external view returns (uint) {
        return s_collateralDeposited[user][token];
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint totalCollateralValueInUsd) {
        for (uint index = 0; index < s_collateralTokens.length; index++) {
            address token = s_collateralTokens[index];
            uint amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function getTokenAmountFromUsd(
        address token,
        uint amountInWei
    ) public view returns (uint) {
        (uint arsxPrice, , ) = s_ARSXOracle.latestData();
        uint usdAmountInWei = (amountInWei * arsxPrice) / ARSX_ORACLE_PRECISION;
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // $100e18 USD Debt
        // 1 ETH = 2000 USD
        // The returned value from Chainlink will be 2000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        return ((usdAmountInWei * PRECISION) /
            (uint(price) * ADDITIONAL_FEED_PRECISION));
    }

    function getPrecision() external pure returns (uint) {
        return PRECISION;
    }

    function getAdditionalFeedPrecision() external pure returns (uint) {
        return ADDITIONAL_FEED_PRECISION;
    }

    function getLiquidationThreshold() external pure returns (uint) {
        return LIQUIDATION_THRESHOLD;
    }

    function getLiquidationBonus() external pure returns (uint) {
        return LIQUIDATION_BONUS;
    }

    function getLiquidationPrecision() external pure returns (uint) {
        return LIQUIDATION_PRECISION;
    }

    function getMinHealthFactor() external pure returns (uint) {
        return MIN_HEALTH_FACTOR;
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getArsx() external view returns (address) {
        return address(i_arsx);
    }

    function getCollateralTokenPriceFeed(
        address token
    ) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getHealthFactor(address user) external view returns (uint) {
        return _healthFactor(user);
    }
}
