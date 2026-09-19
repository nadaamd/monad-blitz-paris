// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {HeatBoard} from "../src/HeatBoard.sol";

contract HeatBoardTest is Test {
    HeatBoard board;
    address alice = address(0xA11CE);
    address bob = address(0xB0B);

    function setUp() public {
        board = new HeatBoard();
    }

    function test_CreateAndCheer() public {
        uint256 id = board.createEntry("HeatBoard");
        assertEq(board.entryCount(), 1);
        assertEq(board.heatOf(id), 0);

        vm.prank(alice);
        board.cheer(id);
        assertEq(board.heatOf(id), 1e18);
    }

    function test_HeatDecaysLinearly() public {
        uint256 id = board.createEntry("HeatBoard");
        vm.prank(alice);
        board.cheer(id);

        vm.warp(block.timestamp + 30 minutes);
        assertEq(board.heatOf(id), 0.5e18);

        vm.warp(block.timestamp + 30 minutes);
        assertEq(board.heatOf(id), 0);
    }

    function test_CheersStack() public {
        uint256 id = board.createEntry("HeatBoard");
        vm.prank(alice);
        board.cheer(id);
        vm.prank(bob);
        board.cheer(id);
        assertEq(board.heatOf(id), 2e18);
    }

    function test_CooldownBlocksSpam() public {
        uint256 id = board.createEntry("HeatBoard");
        vm.startPrank(alice);
        board.cheer(id);
        vm.expectRevert(abi.encodeWithSelector(HeatBoard.StillCoolingDown.selector, 30));
        board.cheer(id);

        vm.warp(block.timestamp + 30);
        board.cheer(id);
        vm.stopPrank();
        assertEq(board.heatOf(id), 2e18 - (uint256(1e18) * 30) / 1 hours);
    }

    function test_RevertsOnUnknownEntry() public {
        vm.expectRevert(HeatBoard.UnknownEntry.selector);
        board.cheer(42);
    }

    function test_RevertsOnEmptyName() public {
        vm.expectRevert(HeatBoard.EmptyName.selector);
        board.createEntry("");
    }

    function test_BoardView() public {
        uint256 id = board.createEntry("HeatBoard");
        vm.prank(alice);
        board.cheer(id);

        (string[] memory names, uint256[] memory heat, uint64[] memory cheers, address[] memory creators) =
            board.board();
        assertEq(names[0], "HeatBoard");
        assertEq(heat[0], 1e18);
        assertEq(uint256(cheers[0]), 1);
        assertEq(creators[0], address(this));
    }
}
