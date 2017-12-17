pragma solidity ^0.4.18;

import './safeMath.sol';

contract cold_staking {
    
        using SafeMath for uint256;
        
        struct Staker
        {
            uint256 weight;
            uint256 init_block;
            uint256 last_claim_block;
        }
        
        uint256 public staking_pool;
        uint256 public reward_pool;
        
        uint256 public reward_per_block = 400000000000000000;
        
        uint256 public staking_threshold = 1000 ether;
        
        mapping (address => Staker) staker;
        
        function() payable
        {
            require(msg.value > 0);
            reward_pool.add(msg.value);
        }
        
        function become_staker() payable
        {
            assert(msg.value >= staking_threshold);
            staking_pool.add(msg.value);
            staker[msg.sender].weight.add(msg.value);
            staker[msg.sender].init_block = block.number.add(172800);
            staker[msg.sender].last_claim_block = block.number;
        }
        
        function withdraw_stake() only_staker
        {
            staking_pool.sub(staker[msg.sender].weight);
            staker[msg.sender].weight.sub(staker[msg.sender].weight);
        }
        
        function claim() only_staker
        {
            msg.sender.transfer(reward(msg.sender));
            reward_pool = this.balance.sub(staking_pool);
            staker[msg.sender].last_claim_block = block.number;
        }
        
        function reward(address _addr) constant returns (uint256 _reward)
        {
            return (staker[_addr].weight / staking_pool * (block.number.sub(staker[_addr].last_claim_block)) * reward_per_block);
        }
        
        modifier only_staker
        {
            assert(staker[msg.sender].weight > 0);
            _;
        }
        
}
