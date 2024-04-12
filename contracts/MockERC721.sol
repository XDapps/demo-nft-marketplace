// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//******************** Mock ERC-721 ***********************/
// This is a Mock ERC-721 contract for testing purposes.
//
// This contract is for demonstration purposes only.
//***********************************************************/

contract MockERC721 is ERC721 {
    uint256 public tokenCounter;
    constructor(string memory name_, string memory symbol_) ERC721(name_, symbol_) {}

    function mint(address to) external {
        tokenCounter++;
        uint256 tokenId = tokenCounter;
        _mint(to, tokenId);
    }
}
