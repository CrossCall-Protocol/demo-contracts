// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19.0;

import {LoadKey} from "./loadkey.t.sol";
import {EntryPoint, UserOperationLib} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/core/EntryPoint.sol";
// import {UserOperation} from "src/crossCall/utils/UserOperation.sol";
import {SimpleAccountFactory, SimpleAccount, IEntryPoint} from "lib/account-abstraction/contracts/samples/SimpleAccountFactory.sol";
import {HyperlaneIGP} from "src/crossCall/hyperlane/HyperlaneIGP.sol";
// import {IEntryPoint} from "src/crossCall/utils/IEntryPoint.sol";
import {HyperlaneMailbox} from "src/crossCall/hyperlane/HyperlaneMailbox.sol";
import {Paymaster} from "src/crossCall/Paymaster.sol";
import {Escrow, IEscrow} from "src/crossCall/escrow/Escrow.sol";
import {EscrowFactory} from "src/crossCall/escrow/EscrowFactory.sol";
import {Multicall} from "src/multicall/Multicall.sol";
import {PaymasterAndData, PaymasterAndData2} from "src/crossCall/escrow/interfaces/IEscrow.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

// import {EtchERC4337} from "test/erc4337/entrypointEtch.t.sol";
// import "test/erc4337/entrypointArtifacts.t.sol";


contract Utils is LoadKey/*, EtchERC4337*/ {
  using ECDSA for bytes32;
  using MessageHashUtils for bytes32;
  using UserOperationLib for PackedUserOperation;

  struct UserOperationUnpacked {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    uint128 callGasLimit; // accountGasLimits: abi.encodePacked(verificationGasLimit, callGasLimit)
    uint128 verificationGasLimit;
    uint256 preVerificationGas;
    uint256 maxFeePerGas; // gasFees: abi.encode(maxPriorityFeePerGas, maxFeePerGas)
    uint256 maxPriorityFeePerGas;
    address paymaster; // paymasterAndData: abi.encodePacked(paymaster, paymasterVerificationGasLimit, paymasterPostOpGasLimit, paymasterData)
    uint128 paymasterVerificationGasLimit;
    uint128 paymasterPostOpGasLimit;
    bytes paymasterData;
    bytes signature;
  }


// export interface PackedUserOperation {
//   sender: typ.address
//   nonce: typ.uint256
//   initCode: typ.bytes
//   callData: typ.bytes
//   accountGasLimits: typ.bytes32
//   preVerificationGas: typ.uint256
//   gasFees: typ.bytes32
//   paymasterAndData: typ.bytes
//   signature: typ.bytes
// }

  // AA infra (not considering other wallets)
  EntryPoint _entryPoint;
  address _entryPointAddress;
  SimpleAccountFactory _simpleAccountFactory;
  address _simpleAccountFactoryAddress;
  SimpleAccount _simpleAccount;
  address _simpleAccountAddress;

  // CrossCall protocol infra
  Paymaster _CrossCallPaymaster;
  address _CrossCallPaymasterAddress;
  Escrow _CrossCallEscrow;
  address _CrossCallEscrowAddress;
  EscrowFactory _CrossCallEscrowFactory;
  address _CrossCallEscrowFactoryAddress;
  Escrow _UserEscrow;
  address _UserEscrowAddress;

  // needs configuration
  HyperlaneMailbox _hyperlaneMailbox;
  address _hyperlaneMailboxAddress;
  HyperlaneIGP _hyperlaneIGP;
  address _hyperlaneIGPAddress;

  // Custom Muticall
  Multicall _multicall;
  address _multicallAddress;

  // not used yet, but used for basic transfer and later swap
  // Token _token;
  // address _tokenAddress;

  uint256 internal constant _SALT = 0x55; // default salt for wallet init
  address internal constant _SIGNER = address(bytes20(bytes32(keccak256("defaultSigner"))));
  address internal constant _SIGNER2 = address(bytes20(bytes32(keccak256("defaultSigner2"))));
  address internal constant _SOLVER = address(bytes20(bytes32(keccak256("defaultSolver"))));
  address internal constant _ADMIN = address(bytes20(bytes32(keccak256("defaultAdmin"))));

  function setUp() public virtual override {
    super.setUp();

    // _token = new Token("Test Token", "TKN");
    // _tokenAddress = address(_token);

    vm.chainId(11155111);

    // _entryPoint = IEntryPoint(ENTRYPOINT_IMPL_ADDRESS);
    // _entryPointAddress = ENTRYPOINT_IMPL_ADDRESS;
    // _simpleAccountFactory = SimpleAccountFactory(SIMPLE_ACCOUNT_FACTORY_ADDRESS);
    // _simpleAccountFactoryAddress = address(_simpleAccountFactory);

    _entryPoint = new EntryPoint();
    _entryPointAddress = address(_entryPoint);

    _simpleAccountFactory = new SimpleAccountFactory(IEntryPoint(_entryPointAddress));
    _simpleAccountFactoryAddress = address(_simpleAccountFactory);

    _hyperlaneMailbox = new HyperlaneMailbox(uint32(block.chainid));
    _hyperlaneMailboxAddress = address(_hyperlaneMailbox);
    _hyperlaneIGP = new HyperlaneIGP(_hyperlaneMailboxAddress);
    _hyperlaneIGPAddress = address(_hyperlaneIGP);

    _CrossCallPaymaster = new Paymaster(
      _entryPoint,
      _hyperlaneMailboxAddress,
      _hyperlaneIGPAddress,
      _SOLVER
    );

    _CrossCallPaymasterAddress = address(_CrossCallPaymaster);
    // should add deposit
    // should add expected chainid
    // should add accepted asset
    _CrossCallPaymaster.addAcceptedChain(11155111, true);
    _CrossCallPaymaster.addAcceptedAsset(11155111,address(0),true);

    _CrossCallEscrow = new Escrow(
      _hyperlaneMailboxAddress,
      address(0),
      11155111,
      _entryPointAddress,
      address(0),
      _SOLVER
    );
    _CrossCallEscrowAddress = address(_CrossCallEscrow);

    _CrossCallEscrowFactory = new EscrowFactory(_CrossCallEscrowAddress);
    _CrossCallEscrowFactoryAddress = address(_CrossCallEscrowFactory);

    (bytes memory _payload, ) = getEscrowInitCode(_SIGNER);
    _UserEscrowAddress = _CrossCallEscrowFactory.createEscrow(_payload, bytes32(_SALT));
    _UserEscrow = Escrow(payable(_UserEscrowAddress));

    _simpleAccount = _simpleAccountFactory.createAccount(_SIGNER, _SALT);
    _simpleAccountAddress = address(_simpleAccount);

    _multicall = new Multicall();
    _multicallAddress = address(_multicall);
  }

  UserOperationUnpacked public userOperationUnpackedBase = UserOperationUnpacked({
    sender: address(0),
    nonce: 0,
    initCode: new bytes(0),
    callData: new bytes(0),
    callGasLimit: 10000000,
    verificationGasLimit: 20000000,
    preVerificationGas: 20000000,
    maxFeePerGas: 3,
    maxPriorityFeePerGas: 2,
    paymaster: address(0),
    paymasterVerificationGasLimit: 10000000,
    paymasterPostOpGasLimit: 10000000,
    paymasterData: new bytes(0),
    signature: new bytes(0)
  });

  // UserOperation public userOpBase = UserOperation({
  //   sender: address(0),
  //   nonce: 0,
  //   initCode: new bytes(0),
  //   callData: new bytes(0),
  //   callGasLimit: 10000000,
  //   verificationGasLimit: 20000000,
  //   preVerificationGas: 20000000,
  //   maxFeePerGas: 2,
  //   maxPriorityFeePerGas: 1,
  //   paymasterAndData: new bytes(0),
  //   signature: new bytes(0)
  // });

  // PackedUserOperation public packedUserOpBase = PackedUserOperation({
  //   sender: address(0),
  //   nonce: 0,
  //   initCode: new bytes(0),
  //   callData: new bytes(0),
  //   accountGasLimits: 20000000,
  //   preVerificationGas: 20000000,
  //   gasFees: 2,
  //   paymasterAndData: new bytes(0),
  //   signature: new bytes(0)
  // });

  PaymasterAndData public paymasterAndDataBase = PaymasterAndData({
    paymaster: address(0),
    paymasterVerificationGasLimit: 10000000,
    paymasterPostOpGasLimit: 10000000,
    owner: address(0),
    chainId: uint256(0),
    asset: address(0),
    amount: uint256(0)
  });

  PaymasterAndData2 public paymasterAndDataBase2 = PaymasterAndData2({
    paymaster: address(0),
    paymasterVerificationGasLimit: 10000000,
    paymasterPostOpGasLimit: 10000000,
    owner: address(0),
    chainId: uint256(0),
    paymentAsset: address(0),
    paymentAmount: uint256(0),
    transferAsset: address(0),
    transferAmount: uint256(0)
  });

  function getWalletInitCode(address owner_) public view returns(bytes memory initCode_, address sender_) {
    initCode_ = abi.encodePacked(_simpleAccountFactory, abi.encodeWithSignature("createAccount(address,uint256)", owner_, _SALT));
    sender_ = _simpleAccountFactory.getAddress(owner_, _SALT);
  }

  function getEscrowInitCode(address owner_) public view returns(bytes memory initCode_, address sender_) {
    initCode_ = abi.encodeWithSignature("initialize(address,address)", owner_, _CrossCallEscrowAddress);
    sender_ = _CrossCallEscrowFactory.getEscrowAddress(initCode_, bytes32(_SALT));
  }

  function getPackedUserOperation(UserOperationUnpacked memory useropU) public view returns(PackedUserOperation memory useropP) {
    useropP.sender = useropU.sender;
    useropP.nonce = useropU.nonce;
    useropP.initCode = useropU.initCode;
    useropP.callData = useropU.callData;
    useropP.accountGasLimits = bytes32(abi.encodePacked(bytes16(useropU.verificationGasLimit), bytes16(useropU.callGasLimit)));
    useropP.preVerificationGas = useropU.preVerificationGas;
    useropP.gasFees = bytes32(abi.encode(bytes16(uint128(useropU.maxPriorityFeePerGas)), bytes16(uint128(useropU.maxFeePerGas))));
    useropP.paymasterAndData = abi.encodePacked(useropU.paymaster, useropU.paymasterVerificationGasLimit, useropU.paymasterPostOpGasLimit, useropU.paymasterData);
    useropP.signature = useropU.signature;
  }
}