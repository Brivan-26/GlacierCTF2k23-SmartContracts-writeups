// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./ERC20.sol";

contract EvilToken is ERC20 
{
    constructor(address owner, string memory name, string memory symbol) ERC20(name, symbol) 
    {
        _mint(owner, 100_000_000);
    }
}