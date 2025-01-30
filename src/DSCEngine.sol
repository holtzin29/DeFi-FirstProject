//SPDX-License-Identifier: MIT
// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// public
// external
// internal
// private
// internal & private view & pure functions
// external & public view & pure functions

// good best practice is to be writing comments to explain what i am doing

pragma solidity ^0.8.28;
import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import {OracleLib} from "./libraries/OracleLib.sol";

/**
 *@title DecentralizedStableCoin
 *@author Mauro Júnior
 * The system is designed to be as minimal as possible and have the tokens maintain a 1token == $1 Pegged.
 * This stablecoins has the following properties:
 * Exogenous collateral
 * Dollar Pegged
 * Algoritmically Stable
 *
 * It has no governance, no fees and it's only backed by WETH and WBTC
 *
 * This DSC system should always be "overcollateralized". At no point, should the value of all collateral <= the $ backed value of DSC
 *
 * @notice This system is the core of the DSC System. It handles all the logic for minting and reedeming DSC, as well as depositing and
 * withdrawing collateral.
 * @notice This contract is Very based on DAI system(MakerDAO DSS)
 */

contract DSCEngine is ReentrancyGuard {
    //// errors ///
    error DSCEngine__NeedsMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedsAddresessMustBeSameLenght();
    error DSCEngine__TokenNotAllowed();
    error DSCEngine__TransferFailed();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__MintFailed();
    error DSCEngine_HealthFactorOk();
    error DSCEngine__HealthFactorNotImproved();

    //// types ////
    using OracleLib for AggregatorV3Interface;

    //// state variables ////
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant LIQUIDATION_THRESHOLD = 50; // 200% overcollateral
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus

    mapping(address token => address priceFeed) private s_priceFeeds; // map tokens to price feeds
    mapping(address user => mapping(address collateralToken => uint256 amount))
        private s_collateralDeposited; // a mapping of the users balance to a mapping of tokens to the amount of token they have.
    mapping(address user => uint256 amountDscMinted) private s_DSCMinted;

    address[] private s_collateralTokens;

    DecentralizedStableCoin private immutable i_dsc;

    //// events ////
    event CollateralDeposited(
        address indexed user,
        address indexed token,
        uint256 indexed amount
    );
    event CollateralRedeemed(
        address indexed redeemedFrom,
        address indexed redeemedTo,
        address indexed token,
        uint256 amount
    );

    //// modifiers ////
    modifier moreThanZero(uint256 amount) {
        if (amount == 0) {
            revert DSCEngine__NeedsMoreThanZero();
        }
        _;
    }
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert DSCEngine__TokenNotAllowed();
        }
        _;
    }

    //// functions /////
    constructor(
        address[] memory tokenAddresses,
        address[] memory priceFeedAddresses,
        address dscAddress
    ) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert DSCEngine__TokenAddressAndPriceFeedsAddresessMustBeSameLenght();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i] = priceFeedAddresses[i]]; // whatever the token, the price feed of i = priceFeed of i
            s_collateralTokens.push(tokenAddresses[i]);
        } // if they have a priceFeed they are allowed
        i_dsc = DecentralizedStableCoin(dscAddress);
    }

    //// external and public functions ///

    /*
     * @param tokenCollateralAddress = the address of token to deposit as collateral
     * @param amountCollateral = the amount of collateral to deposit
     * @param amountDscToMint = The amount of decentralized stablecoin to mint
     * @notice this function will deposit your collateral and mint your dsc in one transaction.
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToMint
    ) public {
        this.depositCollateral(tokenCollateralAddress, amountCollateral); // should i add this.depositcollateral?
        mintDsc(amountDscToMint);
    }

    /*
     * @param tokenCollateralAddress = The address of the token to deposit as collateral
     * @param amountCollateral = The amount of collateral to deposit
     */

    function depositCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    )
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        s_collateralDeposited[msg.sender][
            tokenCollateralAddress
        ] += amountCollateral;
        emit CollateralDeposited(
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        ); // emits an event of msg.sender to tokencollateral addres with an amount
        bool success = IERC20(tokenCollateralAddress).transferFrom(
            msg.sender,
            address(this),
            amountCollateral
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
    }

    /*
     *@param tokenCollateralAddress = the collateral address to redeem
     *@param amountCollateral = the amount of collateral to redeem
     *@param amountDscToBurn = the amount of dsc to burn
     *This function burns DSC and reedems collateral in one transaction
     */
    function redeemCollateralForDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountDscToBurn
    ) external {
        burnDsc(amountDscToBurn); // burns dsc first to then reedem collateral
        _redeemCollateral(
            msg.sender,
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        ); // redeemCollateral already Checks HealthFactor.
    }

    //in order to reedem collateral they must have:
    // health factor>1 after collateral pulled
    function redeemCollateral(
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) external moreThanZero(amountCollateral) nonReentrant {
        _redeemCollateral(
            msg.sender,
            msg.sender,
            tokenCollateralAddress,
            amountCollateral
        );
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /*
     * @notice follows CEI
     * @param amountDscToMint = the amount of decentralized stable coin to mint
     * @notice collateral value > minimum threshold
     */

    function mintDsc(
        uint256 amountDscToMint
    ) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);
        if (!minted) {
            revert DSCEngine__MintFailed();
        }
    }

    // we put uint256 as parameters and with modifier to people burn any amount they want
    function burnDsc(uint256 amount) public moreThanZero(amount) {
        _burnDsc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender); // thinking of removing this line because it will not break their health factor if they tryin to burn
    }

    /*
     * Returns how close to liquidation an user is
     * If a user goes below 1, they can have liquidated.
     */
    function _healthFactor(address user) private view returns (uint256) {
        // total dsc minted
        // total collateral value
        (
            uint256 totalDscMinted,
            uint256 collateralValueInUsd
        ) = _getAccountInformation(user);
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd); // this is your health factor
        // example of the above statement 1000$ eth * 50 = 50000/100 = 500DSC // you need to have the double the collateral
        // your health factor example $1000 eth 100dsc your health will be 1000 * 50 = 50000 /100 = (500/100) = 5>1
        // return(collateralValueInUsd / totalDscMinted);
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert DSCEngine__BreaksHealthFactor(); // should it have user health function there?
        }
    }

    /*
     *@param collateral = The erc20 collateral address to liquidate from the user
     *@param user = the user who has broken the health factor
     *@param debtToCover = the amount of DSC you want to burn to improve the user healthfactor
     *@notice you can partially liquidate the user
     *@notice you will get a liquidation bonus for taking the user funds.
     *@notice this function working assumes the protocol will be roughly 200% overcollateralized in order to work.
     *@notice a known bug would if a protocol were 100% or less collaterizd, there wouldn't be any liquidators.
     * Checks CEI
     */
    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover
    ) external moreThanZero(debtToCover) nonReentrant {
        // checks user health factor
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert DSCEngine_HealthFactorOk();
        }
        // burn the dsc debt and take their collateral
        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(
            collateral,
            debtToCover
        );
        // giving them a 10% bonus for liquidating for us // our protocol always should have more collateral than minted dsc
        uint256 bonusCollateral = (tokenAmountFromDebtCovered *
            LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateraltoRedeem = tokenAmountFromDebtCovered +
            bonusCollateral;
        _redeemCollateral(
            user,
            msg.sender,
            collateral,
            totalCollateraltoRedeem
        ); // from user to msg sender the collateral token and the total to redeem
        _burnDsc(debtToCover, user, msg.sender); // whoever who calls liquidate is paying the debt to cover

        uint256 endingUserHealthFactor = _healthFactor(user);
        if (endingUserHealthFactor <= startingUserHealthFactor) {
            revert DSCEngine__HealthFactorNotImproved();
        }
        _revertIfHealthFactorIsBroken(msg.sender); // if the process ruin their health factor we shouldn't let them do this
    }

    // external and public view functions //
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    function calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) external pure returns (uint256) {
        return _calculateHealthFactor(totalDscMinted, collateralValueInUsd);
    }

    //// private and internal view functions ////

    function _calculateHealthFactor(
        uint256 totalDscMinted,
        uint256 collateralValueInUsd
    ) private pure returns (uint256) {
        if (totalDscMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd *
            LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDscMinted;
    }

    function _getAccountInformation(
        address user
    )
        private
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /// public and internal view functions ///

    /**
     *
     * @dev low-level functions, do not call it unless function calling is checking healthfactor being broken
     */
    function _burnDsc(
        uint256 amountDscToBurn,
        address onBehalfOf,
        address dscFrom
    ) private {
        s_DSCMinted[onBehalfOf] -= amountDscToBurn; // removes the dsc minted
        bool success = i_dsc.transferFrom(
            dscFrom,
            address(this),
            amountDscToBurn
        );
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burn(amountDscToBurn);
    }

    function _redeemCollateral(
        address from,
        address to,
        address tokenCollateralAddress,
        uint256 amountCollateral
    ) private {
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral; // if they only have like 10 and try to revert 1000 it will revert
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
            revert DSCEngine__TransferFailed();
        }
    }

    function getTokenAmountFromUsd(
        address token,
        uint256 usdAmountInWei
    ) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        return
            (usdAmountInWei * PRECISION) /
            (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    function getAccountCollateralValue(
        address user
    ) public view returns (uint256 totalCollateralValueInUsd) {
        // loop thourgh each collateral token, get the amount they have deposited and map it to price to get the usd value
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += _getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    function _getUsdValue(
        address token,
        uint256 amount
    ) private view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(
            s_priceFeeds[token]
        );
        (, int256 price, , , ) = priceFeed.staleCheckLatestRoundData();
        // 1 ETH = 1000 USD
        // The returned value from Chainlink will be 1000 * 1e8
        // Most USD pairs have 8 decimals, so we will just pretend they all do
        // We want to have everything in terms of WEI, so we add 10 zeros at the end
        return
            ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountInformation(
        address user
    )
        external
        view
        returns (uint256 totalDscMinted, uint256 collateralValueInUsd)
    {
        (totalDscMinted, collateralValueInUsd) = _getAccountInformation(user);
    }

    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    function getCollateralTokenPriceFeed(
        address token
    ) external view returns (address) {
        return s_priceFeeds[token];
    }

    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    function getUsdValue(
        address token,
        uint256 amount // in WEI
    ) external view returns (uint256) {
        return _getUsdValue(token, amount);
    }

    function getCollateralBalanceOfUser(
        address user,
        address token
    ) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    function getDsc() external view returns (address) {
        return address(i_dsc);
    }

    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }
}
