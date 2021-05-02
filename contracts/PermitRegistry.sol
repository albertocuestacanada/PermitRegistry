// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

import "@yield-protocol/utils-v2/contracts/token/IERC20.sol";
import "@yield-protocol/utils-v2/contracts/token/IERC2612.sol";
import "dss-interfaces/src/dss/DaiAbstract.sol";


contract PermitRegistry {
    event PermitRegistered(address indexed token, PermitType indexed permitType);

    enum PermitType { NONE, ERC2612, DAI }

    uint256 public constant MAX = type(uint256).max;

    mapping (address => PermitType) public permits;

    /// @dev Use an ERC2612 permit to register if `token` implements it.
    /// The permit should have this contract as the spender, and type(uint256).max as allowance and deadline.
    /// @notice As a precaution, set the allowance back to zero after registering.
    function registerPermit(address token, uint8 v, bytes32 r, bytes32 s)
        public
    {
        require(permits[token] == PermitType.NONE || permits[token] == PermitType.DAI, "Already set");
        IERC2612(token).permit(msg.sender, address(this), MAX, MAX, v, r, s);
        require(IERC20(token).allowance(msg.sender, address(this)) == MAX, "No ERC2612 permit");
        permits[token] == PermitType.ERC2612;
        emit PermitRegistered(token, PermitType.ERC2612);
    }

    /// @dev se an Dai-style permit to register if `token` implements it.
    /// The permit should have this contract as the spender, and type(uint256).max as deadline.
    /// @notice As a precaution, set the allowance back to zero after registering.
    function registerDaiPermit(address token, uint8 v, bytes32 r, bytes32 s)
        private
    {
        require(permits[token] == PermitType.NONE, "Already set");
        uint256 nonce = DaiAbstract(token).nonces(msg.sender);
        DaiAbstract(token).permit(msg.sender, address(this), nonce, MAX, true, v, r, s);
        require(DaiAbstract(token).allowance(msg.sender, address(this)) == MAX, "No DAI permit");
        permits[token] == PermitType.DAI;
        emit PermitRegistered(token, PermitType.DAI);
    }
}