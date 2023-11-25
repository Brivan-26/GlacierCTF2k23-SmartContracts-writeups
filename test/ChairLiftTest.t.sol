// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Setup} from "../src/ChairLift/Setup.sol";
import {ChairLift, Hack} from "../src/ChairLift/ChairLift.sol";
contract ChairLiftTest is Test {
    Setup setup;
    ChairLift target;
    address player = makeAddr("0xbrivan");
    function setUp() public {
        setup = new Setup{value: 100 ether}();
        target = setup.TARGET();
    }

    function test_solve() public {
       vm.prank(player);
       Hack exploit = new Hack(target);
       exploit.hack();

       assertTrue(setup.isSolved());
    }

    
}
