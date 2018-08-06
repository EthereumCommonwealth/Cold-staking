pragma solidity ^0.4.18;

import './safeMath.sol';

contract ColdStaking {

    using SafeMath for uint256;

    event StartStaking(address addr, uint256 value, uint256 weight, uint256 init_block);
    event WithdrawStake(address staker, uint256 weight);
    event Claim(address staker, uint256 reward);
    event FirstStakeDonation(address _address, uint256 value);


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
    uint256 public round_interval = 200; // approx. 1 month in blocks
    uint256 public max_delay = 7 * 6000; // approx. 1 year in blocks

    mapping(address => Staker) staker;
    mapping(address => bool) private muted;


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


    function First_Stake_donation() public payable {

        emit FirstStakeDonation(msg.sender, msg.value);

    }

    function claim_and_withdraw() public
    {
        claim();
        withdraw_stake();
    }

    function withdraw_stake() public only_staker mutex(msg.sender)
    {
        
        msg.sender.transfer(staker[msg.sender].weight);
        staking_pool = staking_pool.sub(staker[msg.sender].weight);
        staker[msg.sender].weight = staker[msg.sender].weight.sub(staker[msg.sender].weight);
        emit WithdrawStake(msg.sender, staker[msg.sender].weight);

    }

    function claim() public only_staker mutex(msg.sender)
    {
        require(block.number >= staker[msg.sender].init_block.add(round_interval));

        uint256 _reward = stake_reward(msg.sender);
        msg.sender.transfer(_reward);
        staker[msg.sender].init_block = block.number;

        emit Claim(msg.sender, _reward);
    }

    function stake_reward(address _addr) public constant returns (uint256 _reward)
    {
        return (reward() * stakerTimeStake(_addr) * stakerWeightStake(_addr));
    }
    function stakerTimeStake(address _addr) public constant returns (uint256 _time)
    {
        //return ((block.number - staker[_addr].init_block) / round_interval);
        return 1;
    }
    function stakerWeightStake(address _addr) public constant returns (uint256 _stake)
    {
        //return (staker[_addr].weight / (staking_pool + staker[_addr].weight * (stakerTimeStake(_addr) - 1)));
        return 0;
    }

    function report_abuse(address _addr) public only_staker mutex(_addr)
    {
        assert(staker[_addr].weight > 0);
        assert(block.number > staker[_addr].init_block.add(max_delay));

        _addr.transfer(staker[msg.sender].weight);
        staker[_addr].weight = 0;
    }

    function reward() public view returns (uint256)
    {
        return address(this).balance.sub(staking_pool);
    }

    modifier only_staker
    {
        assert(staker[msg.sender].weight > 0);
        _;
    }

    modifier mutex(address _target)
    {
        if (muted[_target])
        {
            revert();
        }

        muted[_target] = true;
        _;
        muted[_target] = false;
    }

    ////////////// DEBUGGING /////////////////////////////////////////////////////////////


    function test() public pure returns (string)
    {
        return "success!";
    }

    function staker_info(address _addr) public constant returns
    (uint256 weight, uint256 init, uint256 stake_time, uint256 _reward)
    {
        if (staker[_addr].init_block == 0)
        {
            return (
            staker[_addr].weight,
            staker[_addr].init_block,
            0,
            stake_reward(_addr)
        );
        }
        return (
        staker[_addr].weight,
        staker[_addr].init_block,
        block.number - staker[_addr].init_block,
        stake_reward(_addr)
        );
    }
}
