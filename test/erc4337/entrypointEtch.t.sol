//SPDX-License-Identifier: MIT
pragma solidity^0.8.23.0;

import "./entrypointArtifacts.t.sol";
import "lib/forge-std/src/Test.sol";


contract EtchERC4337 is Test {

  constructor() { // implementation of old entrypoint
    vm.etch(ENTRYPOINT_IMPL_ADDRESS, ENTRYPOINT_IMPL_BYTECODE);
    vm.etch(SIMPLE_ACCOUNT_FACTORY_ADDRESS, SIMPLE_ACCOUNT_FACTORY_BYTECODE);
    vm.etch(SIMPLE_ACCOUNT_ADDRESS, SIMPLE_ACCOUNT_BYTECODE);
  }

  // function EtchERC4337Contracts() external {
  //   vm.etch(ENTRYPOINT_IMPL_ADDRESS, ENTRYPOINT_IMPL_BYTECODE);
  //   vm.etch(SIMPLE_ACCOUNT_IMPL_ADDRESS, SIMPLE_ACCOUNT_IMPL_BYTECODE);
  // }
}