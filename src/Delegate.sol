// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uma/core/data-verification-mechanism/implementation/VotingV2.sol";

contract Delegate is ERC20, Ownable {

    struct UserRedemption {
        uint128 amount;
        uint128 unstakeRequestIndex;
    }

    

    VotingV2 public voting;
    ERC20 public votingToken;
    bool public isInitialized;
    mapping(address => UserRedemption) public userRedemptions;
    uint128[] public unstakeRequests;
    uint128 public pendingLpToUnstake;

    constructor() ERC20("", "") {
        // Brick the implementation contract.
        isInitialized = true;
        _transferOwnership(address(0));
    }

    function initialize(address _voting, string memory name_suffix, string memory symbol_suffix) public {
        require(!isInitialized, "Already initialized");
        isInitialized = true;
        _transferOwnership(msg.sender);
        voting = VotingV2(_voting);
        votingToken = voting.votingToken();
        _name = string.concat("Delegate Token", name_suffix);
        _symbol = string.concat("DEL", symbol_suffix);
    }

    function addTokens(uint256 _amount) public {
        voting.withdrawAndRestake();
        uint256 balance = voting.voterStakes(address(this)).stake;
        uint256 lpToIssue = totalSupply() * _amount / balance;
        require(votingToken.transferFrom(msg.sender, address(this), _amount), "transferFrom failed");
        require(votingToken.approve(address(voting), _amount), "approve failed");
        voting.stake(_amount);
        _mint(msg.sender, lpToIssue);
    }

    function requestRedemption(uint256 _amount) public {
        voting.withdrawAndRestake();
        Staker.VoterStake memory voterStake = voting.voterStakes(address(this));
        uint256 balance = voterStake.stake;
        uint256 amountOwed = balance * _amount / totalSupply();


        if (voterStake.pendingUnstake != 0 && voterStake.unstakeTime < block.timestamp) {
            voting.executeUnstake();
        }

        if (voterStake.pendingUnstake != 0 && voterStake.unstakeTime >= block.timestamp) {
            // Add to queue.
        } else {
            // Immediately request unstake.
            pendingLpToUnstake += _amount;
            voting.requestUnstake(balance * pendingLpToUnstake / totalSupply());
            unstakeRequests.push(pendingLpToUnstake);
        }

        }
            uint256 pendingUnstake = voterStake.pendingUnstake;
            uint256 pendingUnstakeAmount = pendingUnstake * balance / totalSupply();
            amountOwed += pendingUnstakeAmount;
        }

        voting.withdraw(lpToBurn);
        _burn(msg.sender, _amount);
    }

    function exchangeRate() public view returns (uint256) {
        return voting.exchangeRate();
    }

    function delegate() public {
        voting.setDelegate(owner());
    }
}
