// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.15;

import {Script, console2} from "forge-std/Script.sol";
import "lib/forge-std/src/console.sol";
import {EntryPoint} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {IEntryPoint, SimpleAccountFactory} from "lib/account-abstraction/contracts/samples/SimpleAccountFactory.sol";

contract AADeploy is Script {

  function setUp() public virtual {}

  function run() public {
    EntryPoint entryPoint;
    SimpleAccountFactory simpleAccountFactory;

    vm.startBroadcast();
    entryPoint = new EntryPoint();
    simpleAccountFactory = new SimpleAccountFactory(IEntryPoint(entryPoint));
    vm.stopBroadcast();
  }
}