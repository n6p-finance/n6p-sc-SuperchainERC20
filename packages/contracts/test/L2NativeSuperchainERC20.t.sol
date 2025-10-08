// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// ─────────────────────────────────────────────────────────────
// 🧪 Testing utilities
// ─────────────────────────────────────────────────────────────
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol";

// ─────────────────────────────────────────────────────────────
// 📚 Libraries
// ─────────────────────────────────────────────────────────────
import {PredeployAddresses} from "@interop-lib/libraries/PredeployAddresses.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

// ─────────────────────────────────────────────────────────────
// 🎯 Target contract
// ─────────────────────────────────────────────────────────────
import {L2NativeSuperchainERC20} from "src/L2NativeSuperchainERC20.sol";

/// @title L2NativeSuperchainERC20Test
/// @notice Foundry test suite for Superchain ERC20 token
contract L2NativeSuperchainERC20Test is Test {
    // ─────────────────────────────────────────────────────────────
    // 📌 Constants
    // ─────────────────────────────────────────────────────────────
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER;

    // ─────────────────────────────────────────────────────────────
    // 📌 State
    // ─────────────────────────────────────────────────────────────
    address owner;
    address alice;
    address bob;

    L2NativeSuperchainERC20 public superchainERC20;

    // ─────────────────────────────────────────────────────────────
    // ⚙️ Setup
    // ─────────────────────────────────────────────────────────────
    function setUp() public {
        // Read deployer from .env
        owner = vm.envAddress("DEPLOYER_ADDRESS");

        // Create some mock addresses
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        console.log("Setting up test suite...");
        console.log("Owner (from .env):", owner);
        console.log("Alice:", alice);
        console.log("Bob:", bob);

        // Deploy test token
        superchainERC20 = new L2NativeSuperchainERC20(owner, "Test", "TEST", 18);
        console.log("Deployed ERC20 at:", address(superchainERC20));
    }

    // ─────────────────────────────────────────────────────────────
    // 🧱 Internal helper
    // ─────────────────────────────────────────────────────────────
    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
        console.log("Mock and expect call set for:", _receiver);
    }

    // ─────────────────────────────────────────────────────────────
    // 🧩 Core Tests
    // ─────────────────────────────────────────────────────────────

    function testMetadata() public view {
        console.log("Checking token metadata...");
        assertEq(superchainERC20.name(), "Test");
        assertEq(superchainERC20.symbol(), "TEST");
        assertEq(superchainERC20.decimals(), 18);
    }

    function testFuzz_mintTo_succeeds(address _to, uint256 _amount) public {
        console.log("Minting tokens...");
        console.log("To:", _to, "Amount:", _amount);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(address(0), _to, _amount);

        vm.prank(owner);
        superchainERC20.mintTo(_to, _amount);

        assertEq(superchainERC20.totalSupply(), _amount);
        assertEq(superchainERC20.balanceOf(_to), _amount);
    }

    function testFuzz_mintTo_revertsIfUnauthorized(address _minter, address _to, uint256 _amount) public {
        vm.assume(_minter != owner);
        console.log("Testing unauthorized mint...");

        vm.expectRevert(Ownable.Unauthorized.selector);
        vm.prank(_minter);
        superchainERC20.mintTo(_to, _amount);
    }

    function testRenounceOwnership() public {
        console.log("Renouncing ownership...");

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(owner, address(0));

        vm.prank(owner);
        superchainERC20.renounceOwnership();

        assertEq(superchainERC20.owner(), address(0));
    }

    function testFuzz_transferOwnership_succeeds(address _newOwner) public {
        vm.assume(_newOwner != owner);
        vm.assume(_newOwner != ZERO_ADDRESS);

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(owner, _newOwner);

        vm.prank(owner);
        superchainERC20.transferOwnership(_newOwner);

        assertEq(superchainERC20.owner(), _newOwner);
    }

    function testFuzz_transfer_succeeds(address _sender, uint256 _amount) public {
        vm.assume(_sender != ZERO_ADDRESS);
        vm.assume(_sender != bob);

        vm.prank(owner);
        superchainERC20.mintTo(_sender, _amount);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(_sender, bob, _amount);

        vm.prank(_sender);
        assertTrue(superchainERC20.transfer(bob, _amount));

        assertEq(superchainERC20.balanceOf(_sender), 0);
        assertEq(superchainERC20.balanceOf(bob), _amount);
    }

    function testFuzz_transferFrom_succeeds(address _spender, uint256 _amount) public {
        vm.assume(_spender != ZERO_ADDRESS && _spender != bob && _spender != alice);

        vm.prank(owner);
        superchainERC20.mintTo(bob, _amount);

        vm.prank(bob);
        superchainERC20.approve(_spender, _amount);

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(bob, alice, _amount);

        vm.prank(_spender);
        assertTrue(superchainERC20.transferFrom(bob, alice, _amount));

        assertEq(superchainERC20.balanceOf(alice), _amount);
    }

    function testFuzz_transferInsufficientBalance_reverts(address _to, uint256 _mintAmount, uint256 _sendAmount) public {
        vm.assume(_mintAmount < type(uint256).max);
        _sendAmount = bound(_sendAmount, _mintAmount + 1, type(uint256).max);

        vm.prank(owner);
        superchainERC20.mintTo(address(this), _mintAmount);

        vm.expectRevert(ERC20.InsufficientBalance.selector);
        superchainERC20.transfer(_to, _sendAmount);
    }

    function testFuzz_transferFromInsufficientAllowance_reverts(
        address _to,
        address _from,
        uint256 _approval,
        uint256 _amount
    ) public {
        vm.assume(_from != ZERO_ADDRESS);
        vm.assume(_approval < type(uint256).max);
        _amount = _bound(_amount, _approval + 1, type(uint256).max);

        vm.prank(owner);
        superchainERC20.mintTo(_from, _amount);

        vm.prank(_from);
        superchainERC20.approve(address(this), _approval);

        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        superchainERC20.transferFrom(_from, _to, _amount);
    }
}
