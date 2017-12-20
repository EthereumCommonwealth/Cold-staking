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
        
        uint256 public staking_threshold = 1000 ether;
        uint256 public claim_interval    = 175000; // blocks
        
        mapping (address => Staker) staker;
        
        function() payable
        {
            // No donations accepted! Consider any value deposit
            // is an attempt to become staker.
            become_staker();
        }
        
        function become_staker() payable
        {
            assert(msg.value >= staking_threshold);
            staking_pool.add(msg.value);
            staker[msg.sender].weight.add(msg.value);
            staker[msg.sender].init_block = block.number;
            staker[msg.sender].last_claim_block = block.number;
        }
        
        function withdraw_stake() only_staker
        {
            staking_pool.sub(staker[msg.sender].weight);
            staker[msg.sender].weight.sub(staker[msg.sender].weight);
        }
        
        function claim() only_staker
        {
            require(block.number >= staker[msg.sender].last_claim_block.add(claim_interval));
            msg.sender.transfer(reward(msg.sender));
            staker[msg.sender].last_claim_block = block.number;
        }
        
        function reward(address _addr) constant returns (uint256 _reward)
        {
            return (staker[_addr].weight / staking_pool * reward_pool());
        }
        
        function reward_pool() constant returns (uint256)
        {
            return this.balance.sub(staking_pool);
        }
        
        modifier only_staker
        {
            assert(staker[msg.sender].weight > 0);
            _;
        }
        
}
