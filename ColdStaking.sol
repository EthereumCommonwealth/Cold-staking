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
        //uint256 public claim_delay    = 175000; // 1 month in blocks
        
        uint256 public claim_delay    = 0;
        uint256 public max_delay      = 1750000;
        
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
        
        function withdraw_stake() only_staker mutex(msg.sender)
        {
            msg.sender.transfer(staker[msg.sender].weight);
            staking_pool.sub(staker[msg.sender].weight);
            staker[msg.sender].weight.sub(staker[msg.sender].weight);
        }
        
        function claim() only_staker
        {
            require(block.number >= staker[msg.sender].last_claim_block.add(claim_delay));
            msg.sender.transfer(reward(msg.sender));
            staker[msg.sender].last_claim_block = block.number;
        }
        
        function reward(address _addr) constant returns (uint256 _reward)
        {
            _reward = staker[_addr].weight.mul((block.number.sub(staker[_addr].last_claim_block) / claim_delay) / (reward_pool().add( staker[_addr].weight.mul( block.number.sub(staker[_addr].last_claim_block) / claim_delay ) )) );
        }
        
        function report_abuse(address _addr) only_staker
        {
            assert(staker[_addr].weight > 0);
            assert(block.number > staker[_addr].last_claim_block.add(max_delay));
            
            _addr.transfer(staker[msg.sender].weight);
            staker[_addr].weight = 0;
        }
        
        
        /*
        function delay_round(address _addr) private constant returns (uint256 _rounds)
        {
            
        }*/
        
        function reward_pool() constant returns (uint256)
        {
            return this.balance.sub(staking_pool);
        }
        
        modifier only_staker
        {
            assert(staker[msg.sender].weight > 0);
            _;
        }
        
    
        mapping (address => bool) private muted;
        modifier mutex(address _target)
        {
            if( muted[_target] )
            {
                revert();
            }
        
            muted[_target] = true;
            _;
            muted[_target] = false;
        }
}
