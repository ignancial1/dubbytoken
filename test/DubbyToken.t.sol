// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {DubbyToken} from "../src/DubbyToken.sol";

contract DubbyTokenTest is Test {
    receive() external payable {}
    DubbyToken public token;

    address public owner;
    address public taxWallet;
    address public alice;
    address public bob;

    function setUp() public {
        owner = address(this);
        taxWallet = makeAddr("taxWallet");
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        token = new DubbyToken(taxWallet);
    }

    // ---------------------------------------------------------
    // Deployment
    // ---------------------------------------------------------

    function test_InitialSupplyMintedToDeployer() public view {
        assertEq(token.balanceOf(owner), 1_000_000 * 10 ** token.decimals());
    }

    function test_OwnerIsSetCorrectly() public view {
        assertEq(token.owner(), owner);
    }

    function test_TaxWalletIsSetCorrectly() public view {
        assertEq(token.taxWallet(), taxWallet);
    }

    function test_CannotDeployWithZeroTaxWallet() public {
        vm.expectRevert("Invalid tax wallet address");
        new DubbyToken(address(0));
    }

    // ---------------------------------------------------------
    // Ownership
    // ---------------------------------------------------------

    function test_OwnerCanTransferOwnershipToContract() public {
        // newOwner must be a contract, so we use taxWallet? no - taxWallet is an EOA (makeAddr).
        // deploy a fresh token as the "new owner" contract instead
        DubbyToken newOwnerContract = new DubbyToken(taxWallet);

        token.transferOwnership(address(newOwnerContract));
        assertEq(token.owner(), address(newOwnerContract));
    }

    function test_CannotTransferOwnershipToZeroAddress() public {
        vm.expectRevert("Cannot be zero address");
        token.transferOwnership(address(0));
    }

    function test_CannotTransferOwnershipToEOA() public {
        vm.expectRevert("New owner must be a contract");
        token.transferOwnership(alice); // alice is a plain address, not a contract
    }

    function test_NonOwnerCannotTransferOwnership() public {
        vm.prank(alice);
        vm.expectRevert("Not contract owner");
        token.transferOwnership(bob);
    }

    // ---------------------------------------------------------
    // Blacklist
    // ---------------------------------------------------------

    function test_OwnerCanBlacklist() public {
        token.blacklist(alice);
        assertTrue(token.isBlacklisted(alice));
    }

    function test_OwnerCanUnblacklist() public {
        token.blacklist(alice);
        token.unblacklist(alice);
        assertFalse(token.isBlacklisted(alice));
    }

    function test_NonOwnerCannotBlacklist() public {
        vm.prank(alice);
        vm.expectRevert("Not contract owner");
        token.blacklist(bob);
    }

    function test_BlacklistedSenderCannotTransfer() public {
        token.blacklist(owner);
        vm.expectRevert("Blacklisted address");
        token.transfer(alice, 100);
    }

    function test_BlacklistedRecipientCannotReceiveTransfer() public {
        token.blacklist(alice);
        vm.expectRevert("Blacklisted address");
        token.transfer(alice, 100);
    }

    // ---------------------------------------------------------
    // Tax exemption
    // ---------------------------------------------------------

    function test_OwnerCanSetTaxExempt() public {
        token.setTaxExempt(alice, true);
        assertTrue(token.isTaxExempt(alice));
    }

    function test_TaxExemptAddressPaysNoTaxOnTransfer() public {
        token.setTaxExempt(owner, true);

        uint256 amount = 1000 * 10 ** token.decimals();
        token.transfer(alice, amount);

        assertEq(token.balanceOf(alice), amount);
    }

    // ---------------------------------------------------------
    // Transfer + tax logic
    // ---------------------------------------------------------

    function test_TransferAppliesFivePercentTax() public {
        uint256 amount = 1000 * 10 ** token.decimals();
        uint256 taxWalletBalanceBefore = token.balanceOf(taxWallet);

        token.transfer(alice, amount);

        uint256 expectedTax = (amount * 5) / 100;
        uint256 expectedNet = amount - expectedTax;

        assertEq(token.balanceOf(alice), expectedNet);
        assertEq(token.balanceOf(taxWallet), taxWalletBalanceBefore + expectedTax);
    }

    function test_TransferFromAppliesTax() public {
        uint256 amount = 1000 * 10 ** token.decimals();

        token.approve(alice, amount);

        vm.prank(alice);
        token.transferFrom(owner, bob, amount);

        uint256 expectedTax = (amount * 5) / 100;
        uint256 expectedNet = amount - expectedTax;

        assertEq(token.balanceOf(bob), expectedNet);
        assertEq(token.balanceOf(taxWallet), expectedTax);
    }

    // ---------------------------------------------------------
    // Launch / sniper protection
    // ---------------------------------------------------------

    function test_OwnerCanLaunch() public {
        token.launchToken();
        assertTrue(token.launched());
        assertEq(token.launchBlock(), block.number);
    }

    function test_CannotLaunchTwice() public {
        token.launchToken();
        vm.expectRevert("Already launched");
        token.launchToken();
    }

    function test_SniperProtectionBlocksEarlyTransfer() public {
        token.launchToken();
        // still within 5 blocks of launch -> should revert
        vm.expectRevert("Sniper protection active");
        token.transfer(alice, 100);
    }

    function test_TransferWorksAfterSniperWindow() public {
        token.launchToken();
        vm.roll(block.number + 6); // fast-forward 6 blocks
        token.transfer(alice, 100); // should succeed now
        assertGt(token.balanceOf(alice), 0);
    }

    // ---------------------------------------------------------
    // Deposit / withdrawal
    // ---------------------------------------------------------

    function test_DepositTakesTaxAndCreditsBalance() public {
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        token.deposit{value: 1 ether}();

        uint256 expectedTax = (1 ether * 5) / 100;
        uint256 expectedCredit = 1 ether - expectedTax;

        assertEq(token.ethBalance(alice), expectedCredit);
        assertEq(taxWallet.balance, expectedTax);
    }

    function test_CannotDepositZero() public {
        vm.prank(alice);
        vm.expectRevert("Must send ETH");
        token.deposit{value: 0}();
    }

    function test_BlacklistedCannotDeposit() public {
        token.blacklist(alice);
        vm.deal(alice, 1 ether);
        vm.prank(alice);
        vm.expectRevert("Blacklisted address");
        token.deposit{value: 1 ether}();
    }

    function test_WithdrawalReturnsFunds() public {
        vm.deal(alice, 1 ether);
        vm.startPrank(alice);
        token.deposit{value: 1 ether}();

        uint256 balanceBefore = alice.balance;
        token.withdrawal();

        assertGt(alice.balance, balanceBefore);
        assertEq(token.ethBalance(alice), 0);
        vm.stopPrank();
    }

    function test_CannotWithdrawWithZeroBalance() public {
        vm.prank(alice);
        vm.expectRevert("Not enough ETH");
        token.withdrawal();
    }

    // ---------------------------------------------------------
    // Rescue functions
    // ---------------------------------------------------------

    function test_OwnerCanRescueETH() public {
        // send stray ETH directly to the contract
        vm.deal(address(token), 1 ether);

        uint256 ownerBalanceBefore = owner.balance;
        token.rescueETH();

        assertEq(owner.balance, ownerBalanceBefore + 1 ether);
    }

    function test_CannotRescueETHWithZeroBalance() public {
        vm.expectRevert("No ETH to recover");
        token.rescueETH();
    }

    function test_NonOwnerCannotRescueETH() public {
        vm.prank(alice);
        vm.expectRevert("Not contract owner");
        token.rescueETH();
    }
}
