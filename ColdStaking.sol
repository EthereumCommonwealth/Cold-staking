pragma solidity ^0.4.18;

import './safeMath.sol';

contract cold_staking {
    
        using SafeMath for uint256;
        
        struct Staker
        {
            uint256 weight;
            uint256 init_block;
        }
        
        uint256 public staking_pool;
        
        uint256 public staking_threshold = 0 ether;
        
        //uint256 public round_interval    = 172800; // approx. 1 month in blocks
        //uint256 public max_delay      = 172800 * 12; // approx. 1 year in blocks
        
        
        /// TESTING VALUES
        uint256 public round_interval    = 200; // approx. 1 month in blocks
        uint256 public max_delay      = 7 * 6000; // approx. 1 year in blocks
        
        mapping (address => Staker) staker;
        
        function() payable
        {
            // No donations accepted! Consider any value deposit
            // is an attempt to become staker.
            start_staking();
        }
        
        function start_staking() payable
        {
            assert(msg.value >= staking_threshold);
            staking_pool.add(msg.value);
            staker[msg.sender].weight.add(msg.value);
            staker[msg.sender].init_block = block.number;
        }
        
        function claim_and_withdraw()
        {
            claim();
            withdraw_stake();
        }
        
        function withdraw_stake() only_staker mutex(msg.sender)
        {
            msg.sender.transfer(staker[msg.sender].weight);
            staking_pool.sub(staker[msg.sender].weight);
            staker[msg.sender].weight.sub(staker[msg.sender].weight);
        }
        
        function claim() only_staker mutex(msg.sender)
        {
            require(block.number >= staker[msg.sender].init_block.add(round_interval));
            msg.sender.transfer(stake_reward(msg.sender));
            staker[msg.sender].init_block = block.number;
        }
        
        function stake_reward(address _addr) constant returns (uint256 _reward)
        {
            return (reward() * staker[_addr].weight * ((block.number - staker[_addr].init_block) / round_interval) / (staking_pool + ((block.number - staker[_addr].init_block) / round_interval) * staker[_addr].weight));
        }
        
        function report_abuse(address _addr) only_staker
        {
            assert(staker[_addr].weight > 0);
            assert(block.number > staker[_addr].init_block.add(max_delay));
            
            _addr.transfer(staker[msg.sender].weight);
            staker[_addr].weight = 0;
        }
        
        function reward() constant returns (uint256)
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
        
        ////////////// DEBUGGING /////////////////////////////////////////////////////////////
        
        
        function test() constant returns (string)
        {
            return "success!";
        }
        
        function staker_info(address _addr) constant returns (uint256 weight, uint256 init, uint256 stake_time, uint256 reward)
        {
            return (staker[_addr].weight, staker[_addr].init_block, block.number - staker[_addr].init_block, stake_reward(_addr));
        }
}
