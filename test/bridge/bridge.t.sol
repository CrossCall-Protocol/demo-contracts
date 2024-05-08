// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19 .0;

import "test/base/utils.t.sol";
import {Multicall} from "src/multicall/Multicall.sol";
import "forge-std/console.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

contract BridgeTest is Utils {
  using ECDSA for bytes32;
  using MessageHashUtils for bytes32;
  
  function setUp() public virtual override {
    super.setUp();
  }

  // function execute(address dest, uint256 value, bytes calldata func) external {
  //   _requireFromEntryPointOrOwner();
  //   _call(dest, value, func);
  // }
  // function _call(address target, uint256 value, bytes memory data) internal {
  //   (bool success, bytes memory result) = target.call{value: value}(data);
  //   if (!success) {
  //     assembly {
  //       revert(add(result, 32), mload(result))
  //     }
  //   }
  // }
  // function createAccount(
  //   address owner,
  //   uint256 salt
  // ) public returns (SimpleAccount ret) {
  //   address addr = getAddress(owner, salt);
  //   uint256 codeSize = addr.code.length;
  //   if (codeSize > 0) {
  //     return SimpleAccount(payable(addr));
  //   }
  //   ret = SimpleAccount(
  //     payable(
  //       new ERC1967Proxy{salt: bytes32(salt)}(
  //         address(accountImplementation),
  //         abi.encodeCall(SimpleAccount.initialize, (owner))
  //       )
  //     )
  //   );
  // }

  // transfer is usually 0x bytes but now via aa, a function calls the transfer
  function test_CallExecute() public {
    address rando = address(bytes20(keccak256(abi.encode("test wallet"))));
    console.log("rando before", rando, rando.balance);
    vm.deal(_simpleAccountAddress, 50 ether);
    vm.deal(_SIGNER, 50 ether);
    vm.prank(_SIGNER);
    console.log("_simpleAccount", address(_simpleAccount));
    bytes memory payload_ = abi.encodeWithSignature("execute(address,uint256,bytes)", rando, 5 ether, hex"");
    address(_simpleAccount).call(payload_);
    console.log("rando before", rando.balance);
  }

  /** We need three transactions within our execution of the bridge call, this is known as our canonical order
   * (1) We need to fund the paymaster sufficently for any execution costs to call Hyperlane
   * (2) We need to fund the fund the wallet sufficently to execut the users proposed userop
   * (3) We need to execute the users userop
   *
   * We do not know if it matters if this operation is frontrun, likely this only hurts the solver, which is a long tail MEV
   *
   * We intend to use a zk proof validating canonical order and no
   */
  function test_CallCreateAndLockEscrow() public {
    // signer init in multicall, signer2 just multicall
    uint256 gas;
    (bytes memory initCodeEscrow_, address escrowAddress_) = getEscrowInitCode(_SIGNER);
    (bytes memory initCodeEscrow2_, address escrowAddress2_) = getEscrowInitCode(_SIGNER2);
    //_LubanEscrowFactory.createEscrow(initCodeEscrow_2, bytes32(_SALT));
    // struct Call3 {
    //   address target;
    //   uint256 value;
    //   bytes callData;
    // }
    // need to deposit funds
    // then lock funds
    // then check desposit and lock
    vm.deal(_SIGNER, 50 ether);
    vm.deal(_SIGNER2, 50 ether);
    // abi.encode(_LubanEscrowAddress, abi.encodeWithSignature(", arg);)
    vm.startPrank(_SIGNER2);
    Multicall.Call3[] memory calls = new Multicall.Call3[](3);
    calls[0] = Multicall.Call3(_LubanEscrowFactoryAddress, 0, abi.encodeWithSignature("createEscrow(bytes memory,bytes32)", initCodeEscrow2_, bytes32(_SALT)));
    calls[1] = Multicall.Call3(escrowAddress2_, 5 ether, abi.encodeWithSignature("deposit(address,uint256)", address(0), 5 ether));
    calls[2] = Multicall.Call3(escrowAddress2_, 0, abi.encodeWithSignature("extendLock()"));
    gas = gasleft();
    Multicall.Result[] memory results = _multicall.multicallExecuteAll{value: 5 ether}(calls);
    console.log("gas cost: ", gas - gasleft());
    console.log(results[0].success);
    console.log(results[1].success);
    console.log(results[2].success);
    vm.stopPrank();

    vm.startPrank(_SIGNER);
    Multicall.Call3[] memory calls2 = new Multicall.Call3[](2);
    calls[0] = Multicall.Call3(escrowAddress_, 5 ether, abi.encodeWithSignature("deposit(address,uint256)", address(0), 5 ether));
    calls[1] = Multicall.Call3(escrowAddress_, 0, abi.encodeWithSignature("extendLock()"));
    gas = gasleft();
    Multicall.Result[] memory results2 = _multicall.multicallExecuteAll{value: 5 ether}(calls2);
    console.log("gas cost: ", gas - gasleft());
    console.log(results2[0].success);
    console.log(results2[1].success);
    vm.stopPrank();
  }

  function test_CallExecuteEntrypoint() public {
    // getWalletInitCode(address owner_);
    (address signer, uint256 signerPk) = makeAddrAndKey("new signer");
    (bytes memory initCodeEscrow_, address escrowAddress_) = getEscrowInitCode(_SIGNER);
    (bytes memory initCodeEscrow2_, address escrowAddress2_) = getEscrowInitCode(_SIGNER2);

    //_simpleAccountFactory.createAccount(signer, _SALT);
    (bytes memory initCode_, address simpleAccount2_) = getWalletInitCode(signer);

    Multicall.Call3[] memory calls = new Multicall.Call3[](3);
    calls[0] = Multicall.Call3(_LubanEscrowFactoryAddress, 0, abi.encodeWithSignature("createEscrow(bytes memory,bytes32)", initCodeEscrow2_, bytes32(_SALT)));

    address rando = address(bytes20(keccak256(abi.encode("test wallet"))));
    console.log("rando before", rando, rando.balance);
    vm.deal(address(simpleAccount2_), 50 ether);

    UserOperationUnpacked memory userOperationUnpacked = userOperationUnpackedBase;
    userOperationUnpacked.sender = simpleAccount2_;
    userOperationUnpacked.nonce = 0;
    userOperationUnpacked.initCode = initCode_;
    userOperationUnpacked.callData = abi.encodeWithSignature("execute(address,uint256,bytes)", rando, 5 ether, hex"");
    userOperationUnpacked.callGasLimit = 10000000;
    userOperationUnpacked.verificationGasLimit = 20000000;
    userOperationUnpacked.preVerificationGas = 20000000;
    userOperationUnpacked.maxFeePerGas = 3;
    userOperationUnpacked.maxPriorityFeePerGas = 2;
    userOperationUnpacked.paymaster = _LubanPaymasterAddress;
    userOperationUnpacked.paymasterVerificationGasLimit = 10000000;
    userOperationUnpacked.paymasterPostOpGasLimit = 10000000;
    userOperationUnpacked.paymasterData = abi.encodePacked(signer, uint256(11155111), address(0), uint256(5 ether));

    PackedUserOperation memory userop_ = getPackedUserOperation(userOperationUnpacked);

  //   UserOperationUnpacked public userOperationUnpackedBase = UserOperationUnpacked({
  //   sender: address(0),
  //   nonce: 0,
  //   initCode: new bytes(0),
  //   callData: new bytes(0),
  //   callGasLimit: 10000000,
  //   verificationGasLimit: 20000000,
  //   preVerificationGas: 20000000,
  //   maxFeePerGas: 3,
  //   maxPriorityFeePerGas: 2,
  //   paymaster: address(0),
  //   paymasterVerificationGasLimit: 10000000,
  //   paymasterPostOpGasLimit: 10000000,
  //   paymasterData: new bytes(0),
  //   signature: new bytes(0)
  // });

    payable(_entryPointAddress).call{value: 5 ether}(abi.encodeWithSignature("depositTo(address)", _LubanPaymasterAddress));
    payable(_entryPointAddress).call{value: 5 ether}(abi.encodeWithSignature("depositTo(address)", msg.sender));
    payable(_entryPointAddress).call{value: 5 ether}(abi.encodeWithSignature("depositTo(address)", msg.sender));

    
    bytes32 useropHash_ = _entryPoint.getUserOpHash(userop_); // need to deploy new entrypoint/simpleAccount and capture new ABI
    
    (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, useropHash_.toEthSignedMessageHash());
    bytes memory signature = abi.encodePacked(r, s, v);
    console.logBytes(signature);
    address result = ECDSA.recover(useropHash_.toEthSignedMessageHash(), signature);
    console.log("signer: ", signer);
    console.log("result: ", result);
    userOperationUnpacked.signature = signature;
    userop_.signature = signature;
    // console.log("signer: ", ECDSA.recover(useropHash_.toEthSignedMessageHash(), userop_.signature));
    // console.log("signer: ", signer);

    PackedUserOperation[] memory userops_ = new PackedUserOperation[](1);
    userops_[0] = userop_;


    vm.deal(_LubanPaymasterAddress, 50 ether);
    console.log("paymaster before", _entryPoint.balanceOf(_LubanPaymasterAddress));
    // execute userop
    _entryPoint.handleOps(userops_, payable(msg.sender));
    console.log("paymaster after", _entryPoint.balanceOf(_LubanPaymasterAddress));

    console.log("msg sender", msg.sender);
    console.log("enrtypoint", _entryPointAddress);
    console.log("account", simpleAccount2_);


    // console.log("_simpleAccount", address(_simpleAccount));
    // find hashed userop, then sign
    // bytes memory payload_ = 
    // signature: new bytes(0)


  

// UserOperation public userOpBase = UserOperation({
//     sender: address(0),
//     nonce: 0,
//     initCode: new bytes(0),
//     callData: new bytes(0),
//     callGasLimit: 10000000,
//     verificationGasLimit: 20000000,
//     preVerificationGas: 20000000,
//     maxFeePerGas: 2,
//     maxPriorityFeePerGas: 1,
//     paymasterAndData: new bytes(0),
//     signature: new bytes(0)
//   });

// struct PackedUserOperation {
//     address sender;
//     uint256 nonce;
//     bytes initCode;
//     bytes callData;
//     bytes32 accountGasLimits;
//     uint256 preVerificationGas;
//     bytes32 gasFees;
//     bytes paymasterAndData;
//     bytes signature;
// }

//   PaymasterAndData public paymasterAndDataBase = PaymasterAndData({ // need to fix paymasterAndData ordering
//     paymaster: address(0),
//     owner: address(0),
//     chainId: uint256(0),
//     asset: address(0),
//     amount: uint256(0)
//   });
  }

  function test_executeDisbursement() public {
    //HyperlaneMailbox::dispatch(11155111 [1.115e7], 0x0000000000000000000000001804c8ab1f12e6bbf3894d4083f33e07309d1f38, 0x00000000000000000000000000000000000000000000000000000000000000400000000000000000000000001804c8ab1f12e6bbf3894d4083f33e07309d1f38000000000000000000000000907d3e885b8f286f27ed469abb0e317bd62a7fd30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000001312d00000000000000000000000000009896800000000000000000000000000000000000000000000000000000000001312d0000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000582e234dae75c793f67a35089c9d99245e1c58470b5fbfb9cf000000000000000000000000f814aa444c49a5dbbbf8f59a654036a0ede26cce000000000000000000000000000000000000000000000000000000000000005500000000000000000000000000000000000000000000000000000000000000000000000000000084b61d27f600000000000000000000000074bd103dbc4fa5187ca3d0914e560afdb81f5f340000000000000000000000000000000000000000000000004563918244f400000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009cc7183455a4c133ae270771860664b6b7ec320bb10000000000000000000000000098968000000000000000000000000000989680f814aa444c49a5dbbbf8f59a654036a0ede26cce0000000000000000000000000000000000000000000000000000000000aa36a700000000000000000000000000000000000000000000000000000000000000000000000000000000000000004563918244f400000000000000000000000000000000000000000000000000000000000000000000000000415f4b4180c74fa301e8383304c8c43fa267a84674dba6365fd8d415f2ff775ce0446688d4b0145af3a51e98cee6f0fdc66522ed935437baa04b1e4c79214daa1c1c00000000000000000000000000000000000000000000000000000000000000)
    // create escrow
    // add funds to escrow
    // should lock funds, not added yet
    // execute handleDispatch
    // function handleDispatch(uint256 destinationDomain, address recipientAddress, bytes calldata messageBody) external {
    //     bytes memory payload_;
    //     bool success;
    //     payload_ = abi.encodeWithSignature("interchainSecurityModule()");
    //     (success, ) = recipientAddress.call(payload_);
    //     require(success); // hyperlane required ISM is defined (even if zero)
    //     payload_ = abi.encodeWithSignature(
    //         "handle(uint32,bytes32,bytes)",
    //         uint32(uint256(destinationDomain)),
    //         bytes32(bytes20(msg.sender)),
    //         messageBody
    //     );
    //     (success, ) = recipientAddress.call(payload_);
    //     require(success, "recipient execution failed");
    // }
    (address signer, uint256 signerPk) = makeAddrAndKey("new signer");
    (bytes memory _payload, ) = getEscrowInitCode(signer);
    address escrowAddress_ = _LubanEscrowFactory.createEscrow(_payload, bytes32(_SALT));
    // should be multicall to calls createEscrow, extendTimelock, and deposit
    IEscrow(escrowAddress_).depositAndLock{value: 5 ether}(address(0), 10 ether);
    //console.log("before(0x1804c8ab1f12e6bbf3894d4083f33e07309d1f38).balance 
    // escrow needs to be fixed
    console.log(msg.sender);
    console.log("msg.sender before", (0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38).balance);
    console.log("escrow before    ", (escrowAddress_).balance);
    _hyperlaneMailbox.handleDispatch(
      11155111, 
      escrowAddress_, 
      hex"0000000000000000000000000000000000000000000000000000000000000020000000000000000000000000907d3e885b8f286f27ed469abb0e317bd62a7fd30000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000012000000000000000000000000000000000000000000000000000000000000001a000000000000000000000000001312d00000000000000000000000000009896800000000000000000000000000000000000000000000000000000000001312d0000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000260000000000000000000000000000000000000000000000000000000000000032000000000000000000000000000000000000000000000000000000000000000582e234dae75c793f67a35089c9d99245e1c58470b5fbfb9cf000000000000000000000000f814aa444c49a5dbbbf8f59a654036a0ede26cce000000000000000000000000000000000000000000000000000000000000005500000000000000000000000000000000000000000000000000000000000000000000000000000084b61d27f600000000000000000000000074bd103dbc4fa5187ca3d0914e560afdb81f5f340000000000000000000000000000000000000000000000004563918244f400000000000000000000000000000000000000000000000000000000000000000060000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000009cc7183455a4c133ae270771860664b6b7ec320bb10000000000000000000000000098968000000000000000000000000000989680f814aa444c49a5dbbbf8f59a654036a0ede26cce0000000000000000000000000000000000000000000000000000000000aa36a700000000000000000000000000000000000000000000000000000000000000000000000000000000000000004563918244f400000000000000000000000000000000000000000000000000000000000000000000000000415f4b4180c74fa301e8383304c8c43fa267a84674dba6365fd8d415f2ff775ce0446688d4b0145af3a51e98cee6f0fdc66522ed935437baa04b1e4c79214daa1c1c000000000000000000000000000000000000000000000000000000000000000000000000000000000000001804c8ab1f12e6bbf3894d4083f33e07309d1f38"
    );
    console.log("msg.sender after ", (0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38).balance);
    console.log("escrow after     ", (escrowAddress_).balance);
    console.logBytes(abi.encode(bytes32(uint256(uint160(msg.sender)))));

    // handleDispatch(11155111, , bytes calldata messageBody)
  }
}
