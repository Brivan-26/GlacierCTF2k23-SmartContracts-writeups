// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {Setup} from "../src/GlacierVault/Setup.sol";
import {Guardian, Hack} from "../src/GlacierVault/Guardian.sol";
contract GlacierVaultTest is Test {
    Setup setup;
    Guardian target;
    address player = makeAddr("0xbrivan");
    function setUp() public {
        setup = new Setup();
        target = setup.TARGET();
    }

    function test_solve() public {
        vm.prank(player);
        Hack exploit = new Hack(target);
        exploit.hack{value: 1337}();


        assertTrue(setup.isSolved());
    }

    
}
