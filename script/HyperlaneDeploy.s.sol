// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import {HyperlaneIGP} from "src/crossCall/hyperlane/HyperlaneIGP.sol";
import {HyperlaneMailbox} from "src/crossCall/hyperlane/HyperlaneMailbox.sol";

contract HyperlaneDeploy is Script {
    uint32 domain;

    function setUp() public {
        domain = uint32(uint256(bytes32((vm.envBytes("BITLAYER_TESTNET_ID")))));
    }

    function run() public {
        vm.startBroadcast();
        HyperlaneMailbox hyperlaneMailbox = new HyperlaneMailbox(domain);
        HyperlaneIGP hyperlaneIGP = new HyperlaneIGP(address(hyperlaneMailbox));
        
        vm.stopBroadcast();
    }
}
