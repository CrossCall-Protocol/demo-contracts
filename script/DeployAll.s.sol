// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import "forge-std/console.sol";
import {Escrow} from "src/crossCall/escrow/Escrow.sol";
import {EscrowFactory} from "src/crossCall/escrow/EscrowFactory.sol";
import {Paymaster} from "src/crossCall/Paymaster.sol";
import {HyperlaneIGP} from "src/crossCall/hyperlane/HyperlaneIGP.sol";
import {HyperlaneMailbox} from "src/crossCall/hyperlane/HyperlaneMailbox.sol";
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
    vm.startBroadcast();
    EntryPoint entrypoint_ = new EntryPoint();
    console.log("EntryPoint deployed: ", address(entrypoint_));
    SimpleAccountFactory simpleAccountFactory_ = new SimpleAccountFactory(entrypoint_);
    console.log("SimpleAccountFactory deployed: ", address(simpleAccountFactory_));
    Multicall multicall_ = new Multicall();
    console.log("Multicall deployed: ", address(multicall_));

    HyperlaneMailbox hyperlaneMailbox_ = new HyperlaneMailbox(11155111); // this should not exist
    hyperlaneMailbox_.setDomain(200810, 0.001 ether); // this needs an array input
    hyperlaneMailbox_.setDomain(3636, 0.001 ether);
    hyperlaneMailbox_.setDomain(17000, 0.001 ether);
    console.log("HyperlaneMailbox deployed: ", address(hyperlaneMailbox_));
    HyperlaneIGP hyperlaneIGP_ = new HyperlaneIGP(address(hyperlaneMailbox_));
    console.log("HyperlaneIGP deployed: ", address(hyperlaneIGP_));

    Paymaster paymaster_ = new Paymaster(
      IEntryPoint(address(entrypoint_)),
      address(hyperlaneMailbox_),
      address(hyperlaneIGP_),
      address(0)
    );
    paymaster_.addAcceptedChain(11155111, true); // this needs an array input
    paymaster_.addAcceptedAsset(11155111,address(0),true);
    paymaster_.addAcceptedChain(200810, true);
    paymaster_.addAcceptedAsset(200810,address(0),true);
    paymaster_.addAcceptedChain(3636, true);
    paymaster_.addAcceptedAsset(3636,address(0),true);
    paymaster_.addAcceptedChain(17000, true);
    paymaster_.addAcceptedAsset(17000,address(0),true);
    console.log("Paymaster deployed: ", address(paymaster_));

    Escrow escrow_ = new Escrow(
      address(hyperlaneMailbox_),
      address(0),
      11155111,
      address(entrypoint_),
      address(0),
      0xaeD6b252635DcEF5Ba85dE52173FF040a18CEC6a
    );
    console.log("Escrow deployed: ", address(escrow_));

    EscrowFactory escrowFactory_ = new EscrowFactory(address(escrow_));
    console.log("EscrowFactory deployed: ", address(escrowFactory_));

    vm.stopBroadcast();
  }
}

