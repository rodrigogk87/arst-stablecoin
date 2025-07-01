// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {ARSXEngine} from "../src/ARSXEngine.sol";
import {ARSXStableCoin} from "../src/ARSXStableCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC20Mock} from "./ERC20Mock.sol";
import {MockOracle} from "./MockOracle.sol";
import {ARSMockOracle} from "./ARSMockOracle.sol";

contract ARSXEngineTest is Test {
    ARSXEngine engine;
    ARSXStableCoin stable;
    ERC20Mock collateral;
    MockOracle priceFeed;
    ARSMockOracle arsxOracle;

    address user = address(15);

    function setUp() public {
        // Timestamp aproximado para hoy
        vm.warp(1_757_117_200);

        // Deploy mock tokens and oracles
        collateral = new ERC20Mock("CollateralToken", "COL");
        priceFeed = new MockOracle();
        stable = new ARSXStableCoin(user);
        arsxOracle = new ARSMockOracle();

        address[] memory tokens = new address[](1);
        address[] memory feeds = new address[](1);

        tokens[0] = address(collateral);
        feeds[0] = address(priceFeed);

        engine = new ARSXEngine(
            tokens,
            feeds,
            address(stable),
            address(arsxOracle)
        );
        vm.prank(user);
        stable.transferOwnership(address(engine));

        // Mint collateral tokens to user
        collateral.mint(user, 1000 ether);
        vm.prank(user);
        collateral.approve(address(engine), type(uint256).max);
    }

    function testDepositCollateral() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), 200 ether);
        assertEq(
            engine.getCollateralBalanceOfUser(user, address(collateral)),
            200 ether
        );
        vm.stopPrank();
    }

    function testMintArsx() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), 200 ether);
        engine.mintArsx(50 ether);
        (uint256 minted, ) = engine.getAccountInformation(user);
        assertEq(minted, 50 ether);
        vm.stopPrank();
    }

    function testDepositAndMintTogether() public {
        vm.startPrank(user);
        engine.depositCollateralAndMintArsx(
            address(collateral),
            200 ether,
            50 ether
        );
        (uint256 minted, uint256 collateralValue) = engine
            .getAccountInformation(user);
        assertEq(minted, 50 ether);
        assertGt(collateralValue, 0);
        vm.stopPrank();
    }

    function testRedeemCollateral() public {
        vm.startPrank(user);
        engine.depositCollateral(address(collateral), 100 ether);
        engine.redeemCollateral(address(collateral), 50 ether);
        assertEq(
            engine.getCollateralBalanceOfUser(user, address(collateral)),
            50 ether
        );
        vm.stopPrank();
    }

    function testRedeemCollateralForArsx() public {
        vm.startPrank(user);
        engine.depositCollateralAndMintArsx(
            address(collateral),
            200 ether,
            50 ether
        );
        //approve to burn them
        stable.approve(address(engine), 50 ether);
        engine.redeemCollateralForArsx(address(collateral), 50 ether, 20 ether);
        (uint256 minted, uint256 collateralValue) = engine
            .getAccountInformation(user);
        assertEq(minted, 30 ether);
        assertGt(collateralValue, 0);
        vm.stopPrank();
    }

    function testBurnArsx() public {
        vm.startPrank(user);
        engine.depositCollateralAndMintArsx(
            address(collateral),
            200 ether,
            50 ether
        );
        //approve to burn them
        stable.approve(address(engine), 10 ether);
        engine.burnArsx(10 ether);
        (uint256 minted, ) = engine.getAccountInformation(user);
        assertEq(minted, 40 ether);
        vm.stopPrank();
    }

    function testLiquidate() public {
        address liquidator = address(2);

        collateral.mint(liquidator, 1000 ether);
        vm.startPrank(liquidator);
        collateral.approve(address(engine), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user);
        engine.depositCollateralAndMintArsx(
            address(collateral),
            0.1 ether,
            100_000 ether
        );
        vm.stopPrank();

        priceFeed.setPrice(1000 * 1e8); // ETH cae a $1000

        vm.startPrank(address(engine));
        stable.mint(liquidator, 500 ether);
        vm.stopPrank();

        vm.startPrank(liquidator);
        stable.approve(address(engine), type(uint256).max);

        console.log("Health factor antes:", engine.getHealthFactor(user));

        // Check correcto
        require(engine.getHealthFactor(user) < 1e18, "User no es liquidable");

        engine.liquidate(address(collateral), user, 50 ether);

        console.log("Health factor despues:", engine.getHealthFactor(user));

        vm.stopPrank();
    }
}
