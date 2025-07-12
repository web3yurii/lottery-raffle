// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VmSafe} from "forge-std/Vm.sol";
import {Test} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

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

    modifier raffleEntered() {
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
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

    function testDontAllowEntranceWhenRaffleIsCalculating() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");
        // Act / Assert
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                              CHECK UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testCheckUpkeepReturnsFalseIfHasNoBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotOpen() public raffleEntered {
        // Arrange
        raffle.performUpkeep("");
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfNotEnoughTimePassed() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval - 1);
        vm.roll(block.number + 1);
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueIfConditionsAreMet() public raffleEntered {
        // Arrange
        // Act
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        // Assert
        assert(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                             PERFORM UPKEEP
    //////////////////////////////////////////////////////////////*/
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public raffleEntered {
        // Arrange
        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsEvent() public raffleEntered {
        // Arrange
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        // Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING_WINNER);
        assert(requestId != bytes32(0));
    }

    function testRaffleRevertsIfCheckUpkeepIsFalse() public {
        // Arrange
        vm.prank(player);
        raffle.enterRaffle{value: entranceFee}();
        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, entranceFee, 1, 0, block.timestamp)
        );
        raffle.performUpkeep("");
        vm.stopPrank();
    }

    /*//////////////////////////////////////////////////////////////
                          FULFILL RANDOM WORDS
    //////////////////////////////////////////////////////////////*/
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(uint256 randomRequestId) public raffleEntered {
        // Arrange
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
        // Act / Assert
    }

    function testFulfillRandomWordsPicksWinnerAndResetsRaffle() public raffleEntered {
        // Arrange
        uint256 additionalEntranceFee = 3;
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        for (uint256 i = startingIndex; i < startingIndex + additionalEntranceFee; i++) {
            address playerAddress = address(uint160(i));
            hoax(playerAddress, 1 ether);
            raffle.enterRaffle{value: entranceFee}();
        }
        uint256 startingTimestamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;
        // Act
        vm.recordLogs();
        raffle.performUpkeep("");
        VmSafe.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
        // Assert
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimestamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalEntranceFee + 1);

        assertEq(recentWinner, expectedWinner);
        assertEq(uint(raffleState), 0);
        assertEq(winnerBalance, startingBalance + prize);
        assertGt(endingTimestamp, startingTimestamp);
    }
}
