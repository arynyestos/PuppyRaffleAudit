//SPDX-License-Identifier: MIT
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


pragma solidity 0.8.20;

interface IChallenge {    
    function solveChallenge(uint256 guess, string memory yourTwitterHandle) external;
}

contract Lesson4ChallengeSolver is Ownable, IERC721Receiver  {
    error NFTNotOwnedByContract(uint256 givenAnswer);

    address internal immutable i_deployer;
    IChallenge public constant CHALLENGE_CONTRACT = IChallenge(0xf988Ebf9D801F4D3595592490D7fF029E438deCa); // Sepolia challenge address
    string public constant TWITTER_HANDLE = "@ynyesto";

    constructor() Ownable(msg.sender) {
        i_deployer = msg.sender;
        transferOwnership(address(this));
    }

    function solveChallenge() external {
        CHALLENGE_CONTRACT.solveChallenge(0, ""); // Irrelevant, will go to else, since myVal == 0
    }

    function go() external {
        uint256 guess =
                uint256(keccak256(abi.encodePacked(address(this), block.prevrandao, block.timestamp))) % 1_000_000;
        CHALLENGE_CONTRACT.solveChallenge(guess, TWITTER_HANDLE);
    }
    
    function onERC721Received(address /*operator*/, address /*from*/, uint256 tokenId, bytes calldata /*data*/) external override returns (bytes4) {
        forwardNFT(msg.sender, tokenId);
        return this.onERC721Received.selector; 
    }

    // This function allows you to safely transfer a NFT to the target address
    function forwardNFT(address nftAddress, uint256 tokenId) private {
        IERC721 nft = IERC721(nftAddress);
        if(nft.ownerOf(tokenId) != address(this)) revert NFTNotOwnedByContract(tokenId);        
        nft.safeTransferFrom(address(this), i_deployer, tokenId);
    }   
}