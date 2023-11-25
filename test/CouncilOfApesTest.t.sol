// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Setup} from "../src/CouncilOfApes/Setup.sol";
import {IcyExchange, Hack} from "../src/CouncilOfApes/IcyExchange.sol";
contract CouncilOfApesTest is Test {
    Setup setup;
    IcyExchange target;
    address player = makeAddr("0xbrivan");
    function setUp() public {
        setup = new Setup{value: 10 ether}();
        target = setup.TARGET();
    }

    function test_solve() public {
       vm.prank(player);
       Hack exploit = new Hack(target);
       exploit.hack{value: 1 ether}();

       assertTrue(setup.isSolved());
    }

    
}
