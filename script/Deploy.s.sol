// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {HeatBoard} from "../src/HeatBoard.sol";

contract Deploy is Script {
    function run() external {
        vm.startBroadcast();
        HeatBoard board = new HeatBoard();
        board.createEntry("HeatBoard");
        vm.stopBroadcast();
        console.log("HeatBoard deployed at:", address(board));
    }
}
