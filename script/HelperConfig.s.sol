// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.t.sol";

abstract contract Constants {
    uint96 constant MOCK_BASE_FEE = 0.25 ether;
    uint96 constant MOCK_GAS_PRICE_LINK = 1;
    int256 constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 constant SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant LOCAL_CHAIN_ID = 31337;
}

contract HelperConfig is Script, Constants {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint32 callbackGasLimit;
        uint256 subscriptionId;
        address link;
    }

    NetworkConfig public localNetworkConfig;

    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor() {
        networkConfigs[SEPOLIA_CHAIN_ID] = getSepoliaNetworkConfig();
    }

    function getNetworkConfig() public returns (NetworkConfig memory) {
        return getNetworkConfigByChainId(block.chainid);
    }

    function getNetworkConfigByChainId(uint256 chainId) public returns (NetworkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilNetworkConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getSepoliaNetworkConfig() internal pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackGasLimit: 500000,
            subscriptionId: 0x6d1d65a97bfa402a3c3ab78f77a3afdf66a63d7b156c99ceb9286be418c975a5, // 49354040706122981092865939794089764545635191452611533899700296425503030080933
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });
    }

    function getOrCreateAnvilNetworkConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        // mock
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            Constants.MOCK_BASE_FEE, Constants.MOCK_GAS_PRICE_LINK, Constants.MOCK_WEI_PER_UNIT_LINK
        );
        LinkToken link = new LinkToken();
        vm.stopBroadcast();

        localNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            interval: 30 seconds,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            callbackGasLimit: 500000,
            subscriptionId: 1, // This is a mock, so we can set it to any value
            link: address(link)
        });

        return localNetworkConfig;
    }
}
