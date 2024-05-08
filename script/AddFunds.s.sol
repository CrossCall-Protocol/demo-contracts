// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {Escrow} from "src/luban/escrow/Escrow.sol";
import {EscrowFactory} from "src/luban/escrow/EscrowFactory.sol";
import {Paymaster} from "src/luban/Paymaster.sol";
import {HyperlaneIGP} from "src/luban/hyperlane/HyperlaneIGP.sol";
import {HyperlaneMailbox} from "src/luban/hyperlane/HyperlaneMailbox.sol";
import {Multicall} from "src/multicall/Multicall.sol";
import {EntryPoint, IEntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {SimpleAccountFactory} from "lib/account-abstraction/contracts/samples/SimpleAccountFactory.sol";

// deploy script for deploying to 200810 (bitlayer)
contract Deploy is Script {
  uint32 domain;

  function setUp() public {
    domain = uint32(uint256(bytes32((vm.envBytes("BITLAYER_TESTNET_ID")))));
  }

  function run() public {
    address _entryPointAddress = 0x317bBdFbAe7845648864348A0C304392d0F2925F;

    address paymasterAddress = 0xdAE5e7CEBe4872BF0776477EcCCD2A0eFdF54f0e;
    address relayAddress = 0xaeD6b252635DcEF5Ba85dE52173FF040a18CEC6a;
    vm.startBroadcast();
    payable(_entryPointAddress).call{value: 0.1 ether}(abi.encodeWithSignature("depositTo(address)", paymasterAddress));
    payable(_entryPointAddress).call{value: 0.1 ether}(abi.encodeWithSignature("depositTo(address)", relayAddress));
    vm.stopBroadcast();
  }
}
