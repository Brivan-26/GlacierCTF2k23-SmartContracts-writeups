// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Setup} from "../src/GlacierCoin/Setup.sol";
import {GlacierCoin, Hack} from "../src/GlacierCoin/GlacierCoin.sol";
contract GlacierCoinTest is Test {
    Setup setup;
    GlacierCoin target;
    address player = makeAddr("0xbrivan");
    function setUp() public {
        setup = new Setup{value: 100 ether}();
        target = setup.TARGET();
    }

    function test_solve() public {
        vm.prank(player);
        Hack exploit = new Hack(target);
        exploit.hack{value: 1 ether}();

        assertTrue(setup.isSolved());
    }
    
}
