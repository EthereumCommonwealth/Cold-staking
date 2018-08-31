pragma solidity ^0.4.12;

import './safeMath.sol';

contract ColdStaking {
    
    // NOTE: The contract only works for intervals of time > round_interval

    using SafeMath for uint256;

    event StartStaking(address addr, uint256 value, uint256 weight, uint256 init_block);
    event WithdrawStake(address staker, uint256 weight);
    event Claim(address staker, uint256 reward);
    event DonationDeposited(address _address, uint256 value);


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
    uint256 public round_interval = 15; // approx. 1 month in blocks
    uint256 public max_delay = 7 * 6000; // approx. 1 year in blocks

    mapping(address => Staker) staker;


    function() public payable
    {
        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        start_staking();
    }

    function start_staking() public payable
    {
        assert(msg.value >= staking_threshold);
        staking_pool = staking_pool.add(msg.value);
        staker[msg.sender].weight = staker[msg.sender].weight.add(msg.value);
        staker[msg.sender].init_block = block.number;

        emit StartStaking(
            msg.sender,
            msg.value,
            staker[msg.sender].weight,
            staker[msg.sender].init_block
        );


    }


    function DEBUG_donation() public payable {

        emit DonationDeposited(msg.sender, msg.value);

    }

    function claim_and_withdraw() public
    {
        claim();
        withdraw_stake();
    }

    function withdraw_stake() public only_staker
    {
        uint _weight = staker[msg.sender].weight;
        staking_pool = staking_pool.sub(_weight);
        staker[msg.sender].weight = 0;
        msg.sender.transfer(_weight);
        emit WithdrawStake(msg.sender, _weight);
    }

    function claim() public only_staker
    {
        require(block.number >= staker[msg.sender].init_block.add(round_interval));

        uint256 _reward = stake_reward(msg.sender);
        staker[msg.sender].init_block = block.number;
        msg.sender.transfer(_reward);

        emit Claim(msg.sender, _reward);
    }

    function stake_reward(address _addr) public constant returns (uint256 _reward)
    {
        return (staker_time_stake(_addr) * staker_weight_stake(_addr));
    }
    function staker_time_stake(address _addr) public constant returns (uint256 _time)
    {
        return ((block.number - staker[_addr].init_block) / round_interval);
    }
    function staker_weight_stake(address _addr) public constant returns (uint256 _stake)
    {
        return ( (reward() * staker[_addr].weight) / (staking_pool + staker[_addr].weight * (staker_time_stake(_addr) - 1)) );
    }

    function report_abuse(address _addr) public only_staker
    {
        require(staker[_addr].weight > 0);
        require(block.number > staker[_addr].init_block.add(max_delay));
        uint _weight = staker[_addr].weight;
        staker[_addr].weight = 0;
        _addr.transfer(_weight);
    }

    function reward() public constant returns (uint256)
    {
        return address(this).balance.sub(staking_pool);
    }

    modifier only_staker
    {
        require(staker[msg.sender].weight > 0);
        _;
    }


    ////////////// DEBUGGING /////////////////////////////////////////////////////////////

    function staker_info(address _addr) public constant returns
    (uint256 weight, uint256 init, uint256 _stake_time, uint256 _reward)
    {
        _stake_time = 0;
        _reward = 0;
        if (staker[_addr].init_block > 0)
        {
            _stake_time = block.number - staker[_addr].init_block;
        }
        if (block.number - staker[_addr].init_block > round_interval)
        {
            _reward = stake_reward(_addr);
        }
        return (
        staker[_addr].weight,
        staker[_addr].init_block,
        _stake_time,
        _reward
        );
    }
}
