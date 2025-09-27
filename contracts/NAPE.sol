// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

// why? why not :)
contract NAPE is ERC20 {
    constructor(uint256 initialSupply) ERC20("NAPE", "NFX") {
        _mint(msg.sender, initialSupply * 10 ** decimals());
    }
}
