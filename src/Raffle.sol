// Layout of Contract:
// version
// imports
// errors (external)
// events (external)
// interfaces, libraries, contracts
// errors (internal)
// Type declarations
// State variables
// Events (internal)
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFConsumerBaseV2Plus} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title A sample Raffle contract
 * @author Yurii Kovalchuk @web3yurii
 * @dev Implements chainlink VRF for random number generation
 * @notice This contract will handle the logic for entering a raffle, selecting winners, and managing funds.
 */
contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__NotEnoughEth();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UnknownRequestId();

    enum RaffleState {
        OPEN, // 0
        CALCULATING_WINNER // 1

    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    uint256 private immutable i_entranceFee;
    // @dev The interval at which the raffle can be drawn
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    RaffleState private s_raffleState;

    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    uint256 private s_recentRequestId;

    address payable[] private s_players;

    event RaffleEntered(address indexed player, uint256 amount);
    event WinnerPicked(address indexed winner);

    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _keyHash,
        uint256 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2Plus(_vrfCoordinator) {
        i_entranceFee = _entranceFee;
        i_interval = _interval;
        i_keyHash = _keyHash;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //        require(msg.value >= i_entranceFee, "Not enough ETH sent to enter the raffle");
        //        require(msg.value >= i_entranceFee, NotEnoughEth());
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEth();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen(); // Raffle is not open
        }

        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender, msg.value);
    }

    // 0. Automatically called by the Chainlink VRF
    // 1. Get a random number
    // 2. Select a winner
    // 3. Transfer the prize to the winner
    function pickWinner() external {
        // is enough time passed?
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        s_raffleState = RaffleState.CALCULATING_WINNER;

        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_keyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });

        s_recentRequestId = s_vrfCoordinator.requestRandomWords(request);
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    // CEI: Checks, Effects, Interactions
    function fulfillRandomWords(uint256 requestId, uint256[] calldata randomWords) internal override {
        // Checks
        if (requestId != s_recentRequestId) {
            revert Raffle__UnknownRequestId();
        }
        // Effects
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        s_recentWinner = s_players[indexOfWinner];

        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0); // Reset the players array
        emit WinnerPicked(s_recentWinner);

        // Interactions
        (bool success,) = s_recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }
}
