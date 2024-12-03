// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "../src/LoanContract.sol";

contract LoanTest is Test {
    LoanContract loan;
    address user1 = address(0x1);
    address user2 = address(0x2);
    address user3 = address(0x3);

    function setUp() public {
        loan = new LoanContract();
    }

    /*
        User Registration
    */

    function testRegisterValidUser() public {
        vm.prank(user1);
        loan.register("Rishabh", "ABCDE1234F", "123456789012", "9876543210");

        // Verify mapping updates
        (address walletAddress, string memory name, string memory pan, string memory adhar, string memory phone) = loan.BorrowerDetails(user1);
        assertEq(walletAddress, user1);
        assertEq(name, "Rishabh");
        assertEq(pan, "ABCDE1234F");
        assertEq(adhar, "123456789012");
        assertEq(phone, "9876543210");

        // Verify registration status
        bool isRegistered = loan.isRegistered(user1);
        assertTrue(isRegistered);
    }

    function testFailRegisterWithInvalidPAN() public {
        vm.prank(user1);
        loan.register("Alice", "INVALIDPA", "123456789012", "9876543210");
    }

    function testFailRegisterWithEmptyName() public {
        vm.prank(user1);
        loan.register("", "ABCDE1234F", "123456789012", "9876543210");
    }

    /*-------------------------
        Loan Application
    --------------------------*/

    function testApplyLoanValid() public {
        vm.prank(user1);
        loan.register("Rishabh", "ABCDE1234F", "123456789012", "9876543210");

        uint256 applicationId = 0;
        vm.prank(user1);
        loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

        // Verify application details
        (
            uint id,
            address walletAddr,
            uint creationTime,
            uint amountRequired,
            uint interest,
            uint interestPerAmount,
            uint totalAmountRaised,
            uint durationOfContribution,
            uint durationOfDebt
        ) = loan.applications(applicationId);

        assertEq(id, applicationId);
        assertEq(walletAddr, user1);
        assertEq(amountRequired, 1 ether);
        assertEq(interest, 5);
        assertEq(totalAmountRaised, 0);
        assertEq(durationOfContribution, block.timestamp + 30*3600*24);
        assertEq(durationOfDebt, block.timestamp + 30*3600*24 + 60*3600*24);
    }

    function testFailApplyLoanAboveLimit() public {
        vm.prank(user1);
        loan.register("Rishabh", "ABCDE1234F", "123456789012", "9876543210");

        vm.prank(user1);
        loan.applyLoan(3 ether, 5, 100, 30 days, 60 days); // Exceeds maxBorrowingLimit (2 ether)
    }

    // /*-------------------------
    //     Contributions
    // --------------------------*/

    function testContributeValid() public {
        // Register user1 and apply for a loan
        vm.prank(user1);
        loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
        vm.prank(user1);
        loan.applyLoan(2 ether, 5, 100, 30 days, 60 days);

        // User2 contributes
        vm.prank(user2);
        vm.deal(user2, 2 ether);
        vm.prank(user2);
        loan.contribute{value: 0.5 ether}(0);

        // Verify updated application
        (, , , uint amountRequired, , , uint totalAmountRaised, , ) = loan.applications(0);
        assertEq(amountRequired, 1.5 ether);
        assertEq(totalAmountRaised, 0.5 ether);

        // Verify contribution details
        uint256 contributedAmt = loan.contributions(0).contributionAmt(user2);
        assertEq(contributedAmt, 0.5 ether);
    }

    // function testFailContributeWithoutFunds() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

    //     // User2 contributes without sufficient funds
    //     vm.prank(user2);
    //     loan.contribute{value: 0}(0);
    // }

    // function testFailContributeAfterDuration() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 1 days, 60 days);

    //     // Fast forward beyond contribution duration
    //     vm.warp(block.timestamp + 2 days);

    //     vm.prank(user2);
    //     vm.deal(user2, 1 ether);
    //     vm.prank(user2);
    //     loan.contribute{value: 0.5 ether}(0);
    // }

    // /*-------------------------
    //     Loan Modification
    // --------------------------*/

    // function testModifyApplication() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

    //     vm.prank(user1);
    //     loan.modifyApplication(0, 10, 80, 0.5 ether, 60 days, 90 days, "No");

    //     // Verify modifications
    //     (
    //         uint id,
    //         ,
    //         ,
    //         uint amountRequired,
    //         uint interest,
    //         uint interestPerAmount,
    //         ,
    //         uint durationOfContribution,
    //         uint durationOfDebt
    //     ) = loan.applications(0);

    //     assertEq(amountRequired, 1.5 ether);
    //     assertEq(interest, 10);
    //     assertEq(interestPerAmount, 80);
    //     assertGt(durationOfContribution, block.timestamp + 30 days);
    //     assertGt(durationOfDebt, block.timestamp + 90 days);
    // }

    // function testFailModifyByNonOwner() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

    //     // Non-owner tries to modify application
    //     vm.prank(user2);
    //     loan.modifyApplication(0, 10, 80, 0.5 ether, 60 days, 90 days, "No");
    // }

    // /*-------------------------
    //     Repayment
    // --------------------------*/

    // function testRepayLoan() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

    //     vm.prank(user2);
    //     vm.deal(user2, 1 ether);
    //     vm.prank(user2);
    //     loan.contribute{value: 1 ether}(0);

    //     // Fast forward to repayment duration
    //     vm.warp(block.timestamp + 31 days);

    //     vm.prank(user1);
    //     vm.deal(user1, 2 ether);
    //     vm.prank(user1);
    //     loan.payback{value: 1.2 ether}(0); // Assuming calculated full amount = 1.2 ether

    //     // Verify repayment details
    //     (, , , , , , uint totalAmountRaised, , ) = loan.applications(0);
    //     assertEq(totalAmountRaised, 1 ether);
    // }

    // function testFailRepayInsufficientFunds() public {
    //     vm.prank(user1);
    //     loan.register("Alice", "ABCDE1234F", "123456789012", "9876543210");
    //     vm.prank(user1);
    //     loan.applyLoan(1 ether, 5, 100, 30 days, 60 days);

    //     vm.prank(user2);
    //     vm.deal(user2, 1 ether);
    //     vm.prank(user2);
    //     loan.contribute{value: 1 ether}(0);

    //     // Attempt repayment with insufficient funds
    //     vm.prank(user1);
    //     vm.deal(user1, 0.5 ether);
    //     vm.prank(user1);
    //     loan.payback{value: 0.5 ether}(0);
    // }
}
