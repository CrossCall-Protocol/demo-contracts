// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19.0;

// Specific version skips history logs
import "lib/account-abstraction/contracts/core/UserOperationLib.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
// import {OwnableUpgradeable} from "@openzeppelin-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {Payment, PaymasterAndData, PaymasterAndData2, IEscrow, PackedPaymasterAndData} from "./interfaces/IEscrow.sol";

contract Escrow is IEscrow, Initializable, Ownable {
  using Strings for uint256;
  using ECDSA for bytes32;
  using MessageHashUtils for bytes32;
  using UserOperationLib for PackedUserOperation;

  uint256 deadline;
  address eoaOwner;

  // delegate use only
  address public delegateAddress;
  address public eoaRelay;
  address public hyperlaneMailbox;
  address public _interchainSecurityModule;
  uint256 public extendNonce;

  mapping(address => uint256) asset;
  mapping(address => uint256) assetLocked; // address(0) logic not implemented
  mapping(address => uint256) assetLock; // timelock per asset
  mapping(bytes32 => bool) id; // later for sybil resistance

  // delegate use only
  mapping(uint32 => address) public entrypoint;
  mapping(address => bool) public hyperlaneOrigin;

  

  // contract authority
  constructor(
    address hyperlaneMailbox_,
    address hyperlaneOrigin_,
    uint32 domain_,
    address entrypoint_,
    address interchainSecurityModule_,
    address eoaRelay_
  ) Ownable(msg.sender) payable {
    (interchainSecurityModule_); // currently not used
    hyperlaneMailbox = hyperlaneMailbox_;
    hyperlaneOrigin[hyperlaneOrigin_] = true;
    entrypoint[domain_] = entrypoint_;
    eoaRelay = eoaRelay_;
  } 

  // delegate authority
  function initialize(address owner_, address delegateAddress_) initializer public {
    eoaOwner = owner_;
    delegateAddress = delegateAddress_;
  }

  // only relay EOA or owner EOA
  function lock() public {
    // some validation
  }

//=============================================================================
// the value only matters on delegate contract itself
//=============================================================================
  function getHyperlaneMailbox() public view returns(address) {
    return Escrow(payable(delegateAddress)).hyperlaneMailbox();
  }

  function setHyperlaneMailbox(address hyperlaneMailbox_) public onlyOwner() {
    hyperlaneMailbox = hyperlaneMailbox_;
  }

  function getHyperlaneOrigin(address hyperlaneOrigin_) public view returns(bool) {
    return Escrow(payable(delegateAddress)).hyperlaneOrigin(hyperlaneOrigin_);
  }

  function setHyperlaneOrigin(address hyperlaneOrigin_, bool state_) public onlyOwner() {
    hyperlaneOrigin[hyperlaneOrigin_] = state_;
  }

  function getEntrypoint(uint32 domain_) public view returns(address) {
    return Escrow(payable(delegateAddress)).entrypoint(domain_);
  }

  function setEntrypoint(uint32 domain_, address entrypoint_) public onlyOwner() {
    entrypoint[domain_] = entrypoint_;
  }

  function interchainSecurityModule() public view returns(address) {
    return Escrow(payable(delegateAddress))._interchainSecurityModule();
  }

  function setInterchainSecurityModule(address interchainSecurityModule_) public onlyOwner() {
    _interchainSecurityModule = interchainSecurityModule_;
  }

  function getEoaRelay() public view returns(address) {
    return Escrow(payable(delegateAddress)).eoaRelay();
  }

  function setEoaRelay(address eoaRelay_) public onlyOwner() {
    eoaRelay = eoaRelay_;
  }
//=============================================================================

  // only relay EOA or owner EOA
  // should be sig to extend, but nonce for sybil resistance
  function extendLock(uint256 sec_, bytes calldata signature_) public {
    address recovered_ = ECDSA.recover(keccak256(abi.encode(sec_, extendNonce, block.chainid)).toEthSignedMessageHash(), signature_);
    require(recovered_ == owner(), "invalid signature");
    extendNonce++;
    // extend time lock by sec_
  }

  function addHyperlane(address hyperlaneOrigin_, bool state_) public onlyOwner {
    hyperlaneOrigin[hyperlaneOrigin_] = state_;
  }

  // open
  function deposit(address asset_, uint256 amount_) public payable {
    uint256 balanceOf;
    uint256 balanceLocked;
    if(asset_ == address(0)) {
      balanceOf = address(this).balance;
    } else {
      IERC20(asset_).transferFrom(msg.sender, address(this), amount_);
      balanceOf = IERC20(asset_).balanceOf(address(this));
    }
    balanceLocked = assetLocked[asset_];
    asset[asset_] = balanceOf - balanceLocked;
    
    emit newBalance(asset_, balanceOf - balanceLocked);
  }

  function depositAndLock(address asset_, uint256 amount_) public payable {
    uint256 balanceOf;
    uint256 balanceUnlocked;
    if(asset_ == address(0)) {
      balanceOf = address(this).balance;
    } else {
      IERC20(asset_).transferFrom(msg.sender, address(this), amount_);
      balanceOf = IERC20(asset_).balanceOf(address(this));
    }
    balanceUnlocked = asset[asset_];
    assetLocked[asset_] = balanceOf - balanceUnlocked;
    
    emit newBalance(asset_, balanceOf - balanceUnlocked);
  }

  // relay EOA claims from 
  function claim(address asset_, uint256 amount_, address to_) public {
    require(msg.sender == getHyperlaneMailbox()); // this will later be Luban network

    bool success;
    if(asset_ == address(0)) {
      (success,) = payable(to_).call{value: amount_}("");
    } else {
      bytes memory payload_ = abi.encodeWithSignature("transferFrom(address,address,uint256)", address(this), to_, amount_);
      assembly {
        success := call(gas(), asset_, 0, add(payload_, 0x20), mload(payload_), 0,0)
      }
    }

    if(!success) {
      revert TransferFailed();
    }

    if(asset[asset_] < amount_) {
      revert WithdrawRejected("Insufficent balance");
    }

    asset[asset_] = asset[asset_] - amount_;

  }

  function handle( // NEEDS TO BE FIXED FOR PACKED USEROP
    uint32 _origin,
    bytes32 _sender,
    bytes calldata message
    ) external {

    // this will later be hyperlane
    require(msg.sender == getHyperlaneMailbox());
    uint256 length_ = message.length;
    uint256 mlength_ = length_ - 20;

    // deserialize userop and paymasterAndData
    bytes20 receiverEncoded_ = bytes20(message[mlength_:length_]);
    (PackedUserOperation memory userop_) = abi.decode(message[:length_], (PackedUserOperation));
    address receiver_ = address(uint160(receiverEncoded_));
    // revert testerror(abi.encodePacked(receiver_));
    

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

// 0x1234567890123456789012345678901234567890123456789012345678901234
// 0x0000000000000000000000000000000000000000000000000000000000000020 // offset
//   000000000000000000000000907d3e885b8f286f27ed469abb0e317bd62a7fd3 // sender
//   0000000000000000000000000000000000000000000000000000000000000000 // nonce
//   0000000000000000000000000000000000000000000000000000000000000120 // head initCode
//   00000000000000000000000000000000000000000000000000000000000001a0 // head callData
//   00000000000000000000000001312d0000000000000000000000000000989680 // accountGasLimits
//   0000000000000000000000000000000000000000000000000000000001312d00 // preVerificationGas
//   0000000000000000000000000000000200000000000000000000000000000000 // gasFees
//   0000000000000000000000000000000000000000000000000000000000000260 // head paymasterAndData
//   0000000000000000000000000000000000000000000000000000000000000320 // head signature
//   0000000000000000000000000000000000000000000000000000000000000058 // tail initcode (length 58)
//   2e234dae75c793f67a35089c9d99245e1c58470b // factory
//   5fbfb9cf // selector
//   000000000000000000000000f814aa444c49a5dbbbf8f59a654036a0ede26cce // signer
//   0000000000000000000000000000000000000000000000000000000000000055 // salt
//   0000000000000000 // padding
//   0000000000000000000000000000000000000000000000000000000000000084 // tail callData
//   b61d27f600000000000000000000000074bd103dbc4fa5187ca3d0914e560afd // body
//   b81f5f3400000000000000000000000000000000000000000000000045639182 // 64
//   44f4000000000000000000000000000000000000000000000000000000000000
//   0000006000000000000000000000000000000000000000000000000000000000
//   00000000
//   00000000000000000000000000000000000000000000000000000000 // padding
//   000000000000000000000000000000000000000000000000000000000000009c // tail paymaster
//   c7183455a4c133ae270771860664b6b7ec320bb1000000000000000000000000 // body
//   0098968000000000000000000000000000989680f814aa444c49a5dbbbf8f59a
//   654036a0ede26cce000000000000000000000000000000000000000000000000
//   0000000000aa36a7000000000000000000000000000000000000000000000000
//   00000000000000000000000000000000000000004563918244f40000
//   00000000 // padding
//   0000000000000000000000000000000000000000000000000000000000000041 // tail signature
//   5f4b4180c74fa301e8383304c8c43fa267a84674dba6365fd8d415f2ff775ce0
//   446688d4b0145af3a51e98cee6f0fdc66522ed935437baa04b1e4c79214daa1c
//   1c00000000000000000000000000000000000000000000000000000000000000
//   0000000000000000000000001804c8ab1f12e6bbf3894d4083f33e07309d1f38

  //  0x0000000000000000000000000000000000000000000000000000000000000000
  //    000000000000000000000000000000000000000000000000000000000000009c
  //    c7183455a4c133ae270771860664b6b7ec320bb1000000000000000000000000
  //    0098968000000000000000000000000000989680f814aa444c49a5dbbbf8f59a654036a0ede26cce0000000000000000000000000000000000000000000000000000000000aa36a700000000000000000000000000000000000000000000000000000000000000000000000000000000000000004563918244f40000000000000000000000000000000000000000000000000000000000000000000000000041
  
// 0x0000000000000000000000000000000000000000000000000000000000000020
//   0000000000000000000000000000000000000000000000000000000000000060
//   0000000000000000000000000000000000000000000000000000000000000020
//   0000000000000000000000000000000000000000000000000000000000000020
//   0000000000000000000000000000000000000000000000000000000000000260


    uint256 offset = uint256(bytes32(message[256:288])) + 64; // offset + tailOffset + 32
    address paymaster_                      = address(bytes20(message[offset:offset+20]));
    uint128 paymasterVerificationGasLimit_  = uint128(bytes16(message[offset+20:offset+36]));
    uint128 paymasterPostOpGasLimit_        = uint128(bytes16(message[offset+36:offset+52]));
    address owner_                          = address(bytes20(message[offset+52:offset+72]));
    uint256 chainId_                        = uint256(bytes32(message[offset+72:offset+104])); 
    address paymentAsset_                   = address(bytes20(message[offset+104:offset+124]));
    uint256 paymentAmount_                  = uint256(bytes32(message[offset+124:offset+156]));
    

    // hash locally
    bytes32 userOpHash_ = getUserOpHash(userop_, getEntrypoint(uint32(chainId_)), chainId_);

    // validate signature
    (address recovered, ECDSA.RecoverError error,) = ECDSA.tryRecover(userOpHash_.toEthSignedMessageHash(), userop_.signature);
    if (error != ECDSA.RecoverError.NoError) {
      revert BadSignature();
    } else {
      if(recovered != owner_) {
        revert InvalidSignature(owner_, recovered);
      }
    }

    if(paymaster_ == address(0)) { revert InvalidPaymaster(paymaster_); }
    if(chainId_ == uint256(0)) { revert InvalidChain(chainId_); }
    if(owner_ == address(0) || owner_ == address(this)) { revert InvalidOwner(owner_); }

    // if(block.timestamp > deadline) { revert InvalidDeadline(""); }

    // Transfer amount of asset to receiver
    bool success_;
    if(assetLocked[paymentAsset_] < paymentAmount_) { 
      revert InsufficentFunds(owner_, paymentAsset_, paymentAmount_);
    }

    // assetLocked[asset_] = assetLocked[asset_] - paymasterAndData_.amount;

    bytes memory payload_;
    if(paymentAsset_ == address(0)) { // address(0) == ETH
      (success_,) = payable(receiver_).call{value: paymentAmount_}("");
      if (!success_) {
      }
    } else {
      // insufficent address(this) balance will auto-revert
      payload_ = abi.encodeWithSignature(
        "transferFrom(address,address,uint256)", 
        address(this), 
        receiver_, 
        paymentAmount_
      );
      assembly {
        success_ := call(gas(), paymentAsset_, 0, add(payload_, 0x20), mload(payload_), 0, 0)
      }
    }

    if(!success_) { 
      revert PaymasterPaymentFailed(receiver_, paymentAsset_, paymentAmount_); // sender is implient escrow owner
    }

    uint256 escrowBalance_;
    
    if(paymentAsset_ == address(0)) {
      escrowBalance_ = address(this).balance;
    } else {
      payload_ = abi.encodeWithSignature("balanceOf(address)", address(this));
      assembly {
        pop(call(gas(), paymentAsset_, 0, add(payload_, 0x20), mload(payload_), 0, 0x20))
        returndatacopy(0, 0, 0x20)
        escrowBalance_ := mload(0)
      }
    }

    asset[paymentAsset_] = escrowBalance_;

    emit PrintUserOp(userop_);
  }
/**
need to check
asset
amount
 */

  // anyone can claim, will send funds to eoaOwner
  function withdraw(address asset_, uint256 amount_) public {
    uint256 balanceOf;
    uint256 balanceLocked = assetLocked[asset_];
    uint256 balance;
    if(asset_ == address(0)) {
      balanceOf = address(this).balance;

      require(balanceOf >= balanceLocked + amount_);
      balance = balanceOf - balanceLocked - amount_;
      asset[address(0)] = balance;
      payable(eoaOwner).call{value: amount_}("");
    } else {
      balanceOf = IERC20(asset_).balanceOf(address(this));
      
      require(balanceOf >= balanceLocked + amount_);
      balance = balanceOf - balanceLocked - amount_;
      asset[asset_] = balance;
      IERC20(asset_).transferFrom(address(this), eoaOwner, amount_);
    }
    emit newBalance(asset_, balance);
  }

  // backdoor to change time lock mistakes, this will likely change to prover function
  function releaseLock(address asset_) public {
    require(msg.sender == getEoaRelay());
    assetLock[asset_] = 0;
  }

  // hash is not yet sybil resistent
  function hashSeconds(address account_, uint256 seconds_) override public view returns(bytes32) {
    return keccak256(abi.encode(account_, seconds_));
  }

  // PackedUserOpertion is borrowed from ERC4337 EntryPoint
  // Only difference is it forces validation using inputs since Escrow is not in the ERC4337 schema
  // everything is supposed to be in calldata so should be fixed eventually
  function getUserOpHash(PackedUserOperation memory userOp, address entrypoint_, uint256 chainId_) public view returns (bytes32) {
    return keccak256(abi.encode(hash(userOp), entrypoint_, chainId_));
  }

  function hash(PackedUserOperation memory userOp) internal pure returns (bytes32) {
    return keccak256(encode(userOp));
  }

  function encode(PackedUserOperation memory userOp) internal pure returns (bytes memory ret) {
    address sender = userOp.sender;
    uint256 nonce = userOp.nonce;
    bytes32 hashInitCode = keccak256(userOp.initCode);
    bytes32 hashCallData = keccak256(userOp.callData);
    bytes32 accountGasLimits = userOp.accountGasLimits;
    uint256 preVerificationGas = userOp.preVerificationGas;
    bytes32 gasFees = userOp.gasFees;
    bytes32 hashPaymasterAndData = keccak256(userOp.paymasterAndData);

    return abi.encode(
      sender, nonce,
      hashInitCode, hashCallData,
      accountGasLimits, preVerificationGas, gasFees,
      hashPaymasterAndData
    );
  }

  // function calldataKeccak(bytes memory data) pure returns (bytes32 ret) {
  //   assembly ("memory-safe") {
  //     let mem := mload(0x40)
  //     let len := data.length
  //     calldatacopy(mem, data.offset, len)
  //     ret := keccak256(mem, len)
  //   }
  // }

  receive() external payable {}

  // event deposit(address asset, uint256 amount);
  event newBalance(address asset, uint256 amount);
}