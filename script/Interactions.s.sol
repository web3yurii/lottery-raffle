// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, Constants} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.t.sol";

contract CreateSubscription is Script{
    function run() public {
        createSubscriptionUsingConfig();
    }

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getNetworkConfig().vrfCoordinator;
        uint256 subscriptionId = createSubscription(vrfCoordinator);
        return (subscriptionId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator) public returns (uint256) {
        console.log("Creating subscription on chain id: ", block.chainid);
        vm.startBroadcast();
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Subscription created with ID: ", subscriptionId);
        console.log("Please update your helper config with the new subscription ID.");
        return subscriptionId;
    }
}

contract FundSubscription is Script, Constants {
    uint256 private constant FUND_AMOUNT = 1 ether;

    function run() public {
        fundSubscriptionUsingConfig();
    }

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getNetworkConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getNetworkConfig().subscriptionId;
        address linkToken = helperConfig.getNetworkConfig().link;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address link) public {
        console.log("Funding subscription with ID: ", subscriptionId);


        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(link).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
        console.log("Subscription funded successfully.");
    }
}
