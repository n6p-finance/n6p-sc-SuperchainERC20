// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

// Testing utilities
import {Test} from "forge-std/Test.sol";
import "forge-std/console.sol"; // ✅ Add console

// Libraries
import {PredeployAddresses} from "@interop-lib/libraries/PredeployAddresses.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {Ownable} from "@solady/auth/Ownable.sol";
import {ERC20} from "@solady/tokens/ERC20.sol";

// Target contract
import {L2NativeSuperchainERC20} from "src/L2NativeSuperchainERC20.sol";

/// @title L2NativeSuperchainERC20Test
contract L2NativeSuperchainERC20Test is Test {
    address internal constant ZERO_ADDRESS = address(0);
    address internal constant SUPERCHAIN_TOKEN_BRIDGE = PredeployAddresses.SUPERCHAIN_TOKEN_BRIDGE;
    address internal constant MESSENGER = PredeployAddresses.L2_TO_L2_CROSS_DOMAIN_MESSENGER;
    address owner;
    address alice;
    address bob;

    L2NativeSuperchainERC20 public superchainERC20;

    /// @notice Sets up the test suite.
    function setUp() public {
        owner = makeAddr("owner");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        console.log("Setting up test suite...");
        console.log("Owner:", owner);
        console.log("Alice:", alice);
        console.log("Bob:", bob);

        superchainERC20 = new L2NativeSuperchainERC20(owner, "Test", "TEST", 18);
        console.log("Deployed ERC20 at:", address(superchainERC20));
    }

    function _mockAndExpect(address _receiver, bytes memory _calldata, bytes memory _returned) internal {
        vm.mockCall(_receiver, _calldata, _returned);
        vm.expectCall(_receiver, _calldata);
        console.log("Mock and expect call set for:", _receiver);
    }

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

        console.log("Total supply:", superchainERC20.totalSupply());
        console.log("Balance of receiver:", superchainERC20.balanceOf(_to));

        assertEq(superchainERC20.totalSupply(), _amount);
        assertEq(superchainERC20.balanceOf(_to), _amount);
    }

    function testFuzz_mintTo_succeeds(address _minter, address _to, uint256 _amount) public {
        vm.assume(_minter != owner);
        console.log("Trying unauthorized mint...");
        console.log("Caller:", _minter);
        console.log("To:", _to);
        console.log("Amount:", _amount);

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

        console.log("New owner:", superchainERC20.owner());
        assertEq(superchainERC20.owner(), address(0));
    }

    function testFuzz_testTransferOwnership(address _newOwner) public {
        vm.assume(_newOwner != owner);
        vm.assume(_newOwner != ZERO_ADDRESS);

        console.log("Transferring ownership...");
        console.log("Old owner:", owner);
        console.log("New owner:", _newOwner);

        vm.expectEmit(true, true, true, true);
        emit Ownable.OwnershipTransferred(owner, _newOwner);

        vm.prank(owner);
        superchainERC20.transferOwnership(_newOwner);

        console.log("Owner after transfer:", superchainERC20.owner());
        assertEq(superchainERC20.owner(), _newOwner);
    }

    function testFuzz_transfer_succeeds(address _sender, uint256 _amount) public {
        vm.assume(_sender != ZERO_ADDRESS);
        vm.assume(_sender != bob);

        console.log("Testing transfer...");
        console.log("Sender:", _sender);
        console.log("Receiver:", bob);
        console.log("Amount:", _amount);

        vm.prank(owner);
        superchainERC20.mintTo(_sender, _amount);
        console.log("Minted balance for sender:", superchainERC20.balanceOf(_sender));

        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(_sender, bob, _amount);

        vm.prank(_sender);
        assertTrue(superchainERC20.transfer(bob, _amount));

        console.log("Sender balance after:", superchainERC20.balanceOf(_sender));
        console.log("Receiver balance after:", superchainERC20.balanceOf(bob));
    }

    function testFuzz_transferFrom_succeeds(address _spender, uint256 _amount) public {
        vm.assume(_spender != ZERO_ADDRESS);
        vm.assume(_spender != bob);
        vm.assume(_spender != alice);

        console.log("Testing transferFrom...");
        console.log("Spender:", _spender, "Amount:", _amount);

        vm.prank(owner);
        superchainERC20.mintTo(bob, _amount);
        console.log("Minted to bob:", _amount);

        vm.prank(bob);
        superchainERC20.approve(_spender, _amount);
        console.log("Approved spender:", _spender);

        vm.prank(_spender);
        vm.expectEmit(true, true, true, true);
        emit IERC20.Transfer(bob, alice, _amount);
        assertTrue(superchainERC20.transferFrom(bob, alice, _amount));

        console.log("Bob balance after:", superchainERC20.balanceOf(bob));
        console.log("Alice balance after:", superchainERC20.balanceOf(alice));
    }

    function testFuzz_transferInsufficientBalance_reverts(address _to, uint256 _mintAmount, uint256 _sendAmount) public {
        vm.assume(_mintAmount < type(uint256).max);
        _sendAmount = bound(_sendAmount, _mintAmount + 1, type(uint256).max);

        console.log("Testing insufficient balance revert...");
        console.log("Mint:", _mintAmount, "Attempted send:", _sendAmount);

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

        console.log("Testing insufficient allowance revert...");
        console.log("From:", _from);
        console.log("Approval:", _approval);
        console.log("Amount:", _amount);

        vm.prank(owner);
        superchainERC20.mintTo(_from, _amount);

        vm.prank(_from);
        superchainERC20.approve(address(this), _approval);

        vm.expectRevert(ERC20.InsufficientAllowance.selector);
        superchainERC20.transferFrom(_from, _to, _amount);
    }
}
