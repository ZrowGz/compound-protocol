// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./CToken.sol";
import "./interfaces/ICompLike.sol";

/**
 * @title Compound's CErc20 Contract
 * @notice CTokens which wrap an EIP-20 underlying
 * @author Compound
 */
contract CErc20 is CToken, CErc20Interface {
    /**
     * @notice Initialize the new money market
     * @param underlying_ The address of the underlying asset
     * @param comptroller_ The address of the Comptroller
     * @param interestRateModel_ The address of the interest rate model
     * @param initialExchangeRateMantissa_ The initial exchange rate, scaled by 1e18
     * @param name_ ERC-20 name of this token
     * @param symbol_ ERC-20 symbol of this token
     * @param decimals_ ERC-20 decimal precision of this token
     */
    function initialize(
        address underlying_,
        ComptrollerInterface comptroller_,
        InterestRateModel interestRateModel_,
        uint initialExchangeRateMantissa_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) public {
        // CToken initialize does the bulk of the work
        super.initialize(
            comptroller_, 
            interestRateModel_, 
            initialExchangeRateMantissa_, 
            name_, 
            symbol_, 
            decimals_
        );
        // Set underlying and sanity check it
        underlying = underlying_;
        EIP20Interface(underlying).totalSupply();
    }

    /*** User Interface ***/

    /**
     * @notice Sender supplies assets into the market and receives cTokens in exchange
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param mintAmount The amount of the underlying asset to supply
     * @return bool true=success
     */
    function mint(uint mintAmount) override external returns (bool) {
        // bool success = mintInternal(mintAmount);
        // if (!success) {
        //     revert ActionFailure();
        // }
        mintInternal(mintAmount);
        return true;
    }

    /**
     * @notice Sender redeems cTokens in exchange for the underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemTokens The number of cTokens to redeem into underlying
     * return bool true=success
     */
    function redeem(uint redeemTokens) override external { // returns (bool) {
        // bool success = redeemInternal(redeemTokens);
        // return success;
        redeemInternal(redeemTokens);
    }

    /**
     * @notice Sender redeems cTokens in exchange for a specified amount of underlying asset
     * @dev Accrues interest whether or not the operation succeeds, unless reverted
     * @param redeemAmount The amount of underlying to redeem
     * return bool true=success
     */
    function redeemUnderlying(uint redeemAmount) override external { // returns (bool) {
        // bool success = redeemUnderlyingInternal(redeemAmount);
        // return success;
        redeemUnderlyingInternal(redeemAmount);
    }

    /**
      * @notice Sender borrows assets from the protocol to their own address
      * @param borrowAmount The amount of the underlying asset to borrow
      * return bool true=success
      */
    function borrow(uint borrowAmount) override external { // returns (bool) {
        // bool success = borrowInternal(borrowAmount);
        // return success;
        borrowInternal(borrowAmount);
    }

    /**
     * @notice Sender repays their own borrow
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     * return bool true=success
     */
    function repayBorrow(uint repayAmount) override external { // returns (bool) {
        // bool success = repayBorrowInternal(repayAmount);
        // return success;
        repayBorrowInternal(repayAmount);
    }

    /**
     * @notice Sender repays a borrow belonging to borrower
     * @param borrower the account with the debt being payed off
     * @param repayAmount The amount to repay, or -1 for the full outstanding amount
     * return bool true=success
     */
    function repayBorrowBehalf(address borrower, uint repayAmount) override external { // returns (bool) {
        // bool success = repayBorrowBehalfInternal(borrower, repayAmount);
        // return success;
        repayBorrowBehalfInternal(borrower, repayAmount);
    }

    /**
     * @notice The sender liquidates the borrowers collateral.
     *  The collateral seized is transferred to the liquidator.
     * @param borrower The borrower of this cToken to be liquidated
     * @param repayAmount The amount of the underlying borrowed asset to repay
     * @param cTokenCollateral The market in which to seize collateral from the borrower
     * return bool true=success
     */
    function liquidateBorrow(
        address borrower, 
        uint repayAmount, 
        CTokenInterface cTokenCollateral
        ) override external { // returns (bool) {
            // bool success = liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
            // return success;
            liquidateBorrowInternal(borrower, repayAmount, cTokenCollateral);
        }

    /**
     * @notice A public function to sweep accidental ERC-20 transfers to this contract. Tokens are sent to admin (timelock)
     * @param token The address of the ERC-20 token to sweep
     */
    function sweepToken(EIP20NonStandardInterface token) override external {
        // require(msg.sender == admin, "CErc20::sweepToken: only admin can sweep tokens");
        if (msg.sender != admin) {
            revert AddressUnauthorized();
        }
        // require(address(token) != underlying, "CErc20::sweepToken: can not sweep underlying token");
        if (address(token) == underlying) {
            revert InvalidUnderlying();
        }
        uint256 balance = token.balanceOf(address(this));
        token.transfer(admin, balance);
    }

    /**
     * @notice The sender adds to reserves.
     * @param addAmount The amount fo underlying token to add as reserves
     * return uint 0=success, otherwise a failure (see ErrorReporter.sol for details)
     */
    function _addReserves(uint addAmount) override external { // returns (uint) {
        // return _addReservesInternal(addAmount);
        _addReservesInternal(addAmount);
    }

    /*** Safe Token ***/

    /**
     * @notice Gets balance of this contract in terms of the underlying
     * @dev This excludes the value of the current message, if any
     * @return The quantity of underlying tokens owned by this contract
     */
    function getCashPrior() virtual override internal view returns (uint) {
        EIP20Interface token = EIP20Interface(underlying);
        return token.balanceOf(address(this));
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False result from `transferFrom` and reverts in that case.
     *      This will revert due to insufficient balance or insufficient allowance.
     *      This function returns the actual amount received,
     *      which may be less than `amount` if there is a fee attached to the transfer.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferIn(address from, uint amount) virtual override internal returns (uint) {
        // Read from storage once
        address underlying_ = underlying;
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying_);
        uint balanceBefore = EIP20Interface(underlying_).balanceOf(address(this));
        token.transferFrom(from, address(this), amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                       // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                      // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of override external call
                }
                default {                      // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
            // require(success, "TOKEN_TRANSFER_IN_FAILED");
        if (!success) {
            revert TransferFailure();
        }

        // Calculate the amount that was *actually* transferred
        uint balanceAfter = EIP20Interface(underlying_).balanceOf(address(this));
        return balanceAfter - balanceBefore;   // underflow already checked above, just subtract
    }

    /**
     * @dev Similar to EIP20 transfer, except it handles a False success from `transfer` and returns an explanatory
     *      error code rather than reverting. If caller has not called checked protocol's balance, this may revert due to
     *      insufficient cash held in this contract. If caller has checked protocol's balance prior to this call, and verified
     *      it is >= amount, this should not revert in normal conditions.
     *
     *      Note: This wrapper safely handles non-standard ERC-20 tokens that do not return a value.
     *            See here: https://medium.com/coinmonks/missing-return-value-bug-at-least-130-tokens-affected-d67bf08521ca
     */
    function doTransferOut(address payable to, uint amount) virtual override internal {
        EIP20NonStandardInterface token = EIP20NonStandardInterface(underlying);
        token.transfer(to, amount);

        bool success;
        assembly {
            switch returndatasize()
                case 0 {                      // This is a non-standard ERC-20
                    success := not(0)          // set success to true
                }
                case 32 {                     // This is a compliant ERC-20
                    returndatacopy(0, 0, 32)
                    success := mload(0)        // Set `success = returndata` of override external call
                }
                default {                     // This is an excessively non-compliant ERC-20, revert.
                    revert(0, 0)
                }
        }
        // require(success, "TOKEN_TRANSFER_OUT_FAILED");
        if (!success) {
            revert TransferFailure();
        }
    }

    /**
    * @notice Admin call to delegate the votes of the COMP-like underlying
    * @param compLikeDelegatee The address to delegate votes to
    * @dev CTokens whose underlying are not CompLike should revert here
    */
    function _delegateCompLikeTo(address compLikeDelegatee) external {
        // require(msg.sender == admin, "only the admin may set the comp-like delegate");
        if (msg.sender != admin) {
            revert AddressUnauthorized();
        }
        
        CompLike(underlying).delegate(compLikeDelegatee);
    }
}
