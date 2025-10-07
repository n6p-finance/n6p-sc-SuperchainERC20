// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

// Testing utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

// Libraries
import {PredeployAddresses} from "@interop-lib/libraries/PredeployAddresses.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

// Target contracts
import {SuperchainERC20} from "../src/SuperchainERC20.sol";
import {IERC7802} from "@interop-lib/interfaces/IERC7802.sol";
import {L2NativeSuperchainERC20} from "../src/L2NativeSuperchainERC20.sol";

/// @title SuperchainERC20Test
/// @notice Verbose version with console logs for each step and state
contract SuperchainERC20Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    SuperchainERC20 public superchainERC20;

    /// @notice Sets up the test suite.
    function setUp() public {
        console.log("Setting up SuperchainERC20 test suite...");
        superchainERC20 = new L2NativeSuperchainERC20(address(this), "Test", "TEST", 18);
        console.log("Deployed L2NativeSuperchainERC20 at:", address(superchainERC20));
    }

    /// @notice Helper to mock and expect calls.
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        console.log("Mocking call to receiver:", _receiver);
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
    }

    /// @notice Tests the `crosschainMint` function reverts when the caller is not the bridge.
    function testFuzz_crosschainMint_callerNotBridge_reverts(address _caller, address _to, uint256 _amount) public {
        console.log("Testing crosschainMint revert when caller is not bridge...");
        vm.assume(_caller != SUPERCHAIN_TOKEN_BRIDGE);
        console.log("Assumed caller is not bridge:", _caller);

        vm.expectRevert("Unauthorized");
        console.log("Expecting revert 'Unauthorized'...");

        vm.prank(_caller);
        superchainERC20.crosschainMint(_to, _amount);
    }

    /// @notice Tests the `crosschainMint` succeeds and emits correct events.
    function testFuzz_crosschainMint_succeeds(address _to, uint256 _amount) public {
        vm.assume(_to != ZERO_ADDRESS);
        console.log("Testing crosschainMint success...");
        console.log("Recipient:", _to, "Amount:", _amount);

        uint256 totalSupplyBefore = superchainERC20.totalSupply();
        uint256 toBalanceBefore = superchainERC20.balanceOf(_to);
        console.log("Before mint -> totalSupply:", totalSupplyBefore, "balanceOf(to):", toBalanceBefore);

        vm.expectEmit(address(superchainERC20));
        emit IERC20.Transfer(ZERO_ADDRESS, _to, _amount);

        vm.expectEmit(address(superchainERC20));
        emit IERC7802.CrosschainMint(_to, _amount, SUPERCHAIN_TOKEN_BRIDGE);

        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        console.log("Calling crosschainMint as bridge...");
        superchainERC20.crosschainMint(_to, _amount);

        uint256 totalSupplyAfter = superchainERC20.totalSupply();
        uint256 toBalanceAfter = superchainERC20.balanceOf(_to);
        console.log("After mint -> totalSupply:", totalSupplyAfter, "balanceOf(to):", toBalanceAfter);

        assertEq(totalSupplyAfter, totalSupplyBefore + _amount, "Total supply mismatch after mint");
        assertEq(toBalanceAfter, toBalanceBefore + _amount, "Recipient balance mismatch after mint");

        console.log("Mint test completed successfully.");
    }

    /// @notice Tests the `crosschainBurn` function reverts when the caller is not the bridge.
    function testFuzz_crosschainBurn_callerNotBridge_reverts(address _caller, address _from, uint256 _amount) public {
        console.log("Testing crosschainBurn revert when caller is not bridge...");
        vm.assume(_caller != SUPERCHAIN_TOKEN_BRIDGE);
        console.log("Assumed caller is not bridge:", _caller);

        vm.expectRevert("Unauthorized");
        console.log("Expecting revert 'Unauthorized'...");

        vm.prank(_caller);
        superchainERC20.crosschainBurn(_from, _amount);
    }

    /// @notice Tests the `crosschainBurn` burns tokens and emits correct events.
    function testFuzz_crosschainBurn_succeeds(address _from, uint256 _amount) public {
        vm.assume(_from != ZERO_ADDRESS);
        console.log("Testing crosschainBurn success...");
        console.log("From address:", _from, "Amount:", _amount);

        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        console.log("Minting tokens before burn...");
        superchainERC20.crosschainMint(_from, _amount);

        uint256 totalSupplyBefore = superchainERC20.totalSupply();
        uint256 fromBalanceBefore = superchainERC20.balanceOf(_from);
        console.log("Before burn -> totalSupply:", totalSupplyBefore, "balanceOf(from):", fromBalanceBefore);

        vm.expectEmit(address(superchainERC20));
        emit IERC20.Transfer(_from, ZERO_ADDRESS, _amount);

        vm.expectEmit(address(superchainERC20));
        emit IERC7802.CrosschainBurn(_from, _amount, SUPERCHAIN_TOKEN_BRIDGE);

        vm.prank(SUPERCHAIN_TOKEN_BRIDGE);
        console.log("Calling crosschainBurn as bridge...");
        superchainERC20.crosschainBurn(_from, _amount);

        uint256 totalSupplyAfter = superchainERC20.totalSupply();
        uint256 fromBalanceAfter = superchainERC20.balanceOf(_from);
        console.log("After burn -> totalSupply:", totalSupplyAfter, "balanceOf(from):", fromBalanceAfter);

        assertEq(totalSupplyAfter, totalSupplyBefore - _amount, "Total supply mismatch after burn");
        assertEq(fromBalanceAfter, fromBalanceBefore - _amount, "Sender balance mismatch after burn");

        console.log("Burn test completed successfully.");
    }
}
