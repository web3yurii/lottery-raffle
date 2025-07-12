// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";

contract RaffleTest is Test {
    event RaffleEntered(address indexed player, uint256 amount);

    Raffle public raffle;
    HelperConfig public helperConfig;

    uint256 private entranceFee;
    uint256 private interval;
    address private vrfCoordinator;
    bytes32 private keyHash;
    uint256 private subscriptionId;
    uint32 private callbackGasLimit;

    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    address public player = makeAddr("player");

    function setUp() public {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployRaffle();
        HelperConfig.NetworkConfig memory config = helperConfig.getNetworkConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        keyHash = config.gasLane;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        vm.deal(player, STARTING_PLAYER_BALANCE);
    }

    function testRaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    /*//////////////////////////////////////////////////////////////
                              ENTER RAFFLE
    //////////////////////////////////////////////////////////////*/
    function testRaffleRevertsIfYouDontPayEnough() public {
        // Arrange
        vm.startPrank(player);
        // Act
        vm.expectRevert(Raffle.Raffle__NotEnoughEth.selector);
        raffle.enterRaffle();
        vm.stopPrank();
        // Assert
    }

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        // Arrange
        vm.startPrank(player);
        // Act
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
        // Assert
        address actual = raffle.getPlayer(0);
        assertEq(actual, player);
    }

    function testRaffleEmitsEventOnEnter() public {
        // Arrange
        vm.startPrank(player);
        // Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(player, entranceFee);
        raffle.enterRaffle{value: entranceFee}();
        vm.stopPrank();
    }

    function testDontAllowEntranceWhenRaffleIsCalculating() public {
        // Arrange
        vm.startPrank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }
}
