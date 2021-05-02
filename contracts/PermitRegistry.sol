// SPDX-License-Identifier: MIT

pragma solidity >= 0.8.0;

import "@yield-protocol/utils-v2/contracts/token/IERC20.sol";
import "@yield-protocol/utils-v2/contracts/token/IERC2612.sol";
import "dss-interfaces/src/dss/DaiAbstract.sol";


interface IERC1271 {
  /// @dev Should return whether the signature provided is valid for the provided data
  /// @param hash      Hash of the data to be signed
  /// @param signature Signature byte array associated with _data
  function isValidSignature(bytes32 hash, bytes memory signature) external view returns (bytes4 magicValue);
}

interface IERC712 {
    /// @dev Return the ERC712 domain separator
    function DOMAIN_SEPARATOR() external view returns (bytes32);
}


contract PermitRegistry {
    event PermitRegistered(address indexed token, uint8 indexed permitType);
    event DomainRegistered(address indexed token, string indexed name, string indexed version, bytes32 domain);

    uint8 constant public NONE = 0;
    uint8 constant public DAI = 1;
    uint8 constant public ERC2612 = 2;
    uint8 constant public ERC1271 = 4;

    uint256 public constant MAX = type(uint256).max;

    mapping (address => uint8) public permits;
    mapping (address => string) public names;
    mapping (address => string) public versions;
    mapping (address => bytes32) public domains;

    /// @dev Return all known data from a given address.
    function data(address token) public view returns (uint8, string memory, string memory, bytes32) {
        return (permits[token], names[token], versions[token], domains[token]);
    }

    /// @dev Verify if the parameters were used to build a domain separator in a target contract, and store everything if positive.
    function registerDomain(address token, string memory name, string memory version) public {
        uint256 chainId;
        assembly {chainId := chainid()}

        bytes32 domain = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(version)),
                chainId,
                token
            )
        );

        require (domain == IERC712(token).DOMAIN_SEPARATOR(), "Mismatched domains");
        names[token] = name;
        versions[token] = version;
        domains[token] = domain;
        emit DomainRegistered(token, name, version, domain);
    }

    /// @dev Use an ERC2612 permit to register if `token` implements it.
    /// The permit should have this contract as the spender, and type(uint256).max as allowance and deadline.
    /// @notice As a precaution, set the allowance back to zero after registering.
    function registerPermit(address token, uint8 v, bytes32 r, bytes32 s)
        public
    {
        IERC2612(token).permit(msg.sender, address(this), MAX, MAX, v, r, s);
        require(
            IERC20(token).allowance(msg.sender, address(this)) == MAX,
            "No ERC2612"
        );
        permits[token] &= ERC2612;
        emit PermitRegistered(token, ERC2612);
    }

    /// @dev Use an ERC1271 off-chain signature to register if `token` implements it.
    function registerERC1271(address token, bytes32 hash, bytes memory signature)
        public
    {
        require(
            IERC1271(token).isValidSignature(hash, signature) == IERC1271(token).isValidSignature.selector,
            "No ERC1271"
        );
        permits[token] &= ERC1271;
        emit PermitRegistered(token, ERC1271);
    }

    /// @dev Use an Dai-style permit to register if `token` implements it.
    /// The permit should have this contract as the spender, and type(uint256).max as deadline.
    /// @notice As a precaution, set the allowance back to zero after registering.
    function registerDaiPermit(address token, uint8 v, bytes32 r, bytes32 s)
        private
    {
        uint256 nonce = DaiAbstract(token).nonces(msg.sender);
        DaiAbstract(token).permit(msg.sender, address(this), nonce, MAX, true, v, r, s);
        require(
            DaiAbstract(token).allowance(msg.sender, address(this)) == MAX,
            "No DAI permit"
        );
        permits[token] &= DAI;
        emit PermitRegistered(token, DAI);
    }
}