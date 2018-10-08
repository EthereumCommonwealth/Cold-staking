pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {
  function mul(uint a, uint b) internal pure returns (uint) {
    if (a == 0) {
      return 0;
    }
    uint c = a * b;
    require(c / a == b);
    return c;
  }

  function div(uint a, uint b) internal pure returns (uint) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint a, uint b) internal pure returns (uint) {
    require(b <= a);
    return a - b;
  }

  function add(uint a, uint b) internal pure returns (uint) {
    uint c = a + b;
    require(c >= a);
    return c;
  }
}

contract ColdStaking {
    
    // NOTE: The contract only works for intervals of time > round_interval

    using SafeMath for uint;

    event StartStaking(address addr, uint value, uint amount, uint time);
    event WithdrawStake(address staker, uint amount);
    event Claim(address staker, uint reward);
    event DonationDeposited(address _address, uint value);


    struct Staker
    {
        uint amount;
        uint time;
    }

    uint public LastBlock;
    uint public Timestamp;
    uint public TotalStakingWeight;        //total weight = sum (each_staking_amount * each_staking_time)
    uint public TotalStakingAmount; //currently frozen amount for Staking
    uint public StakingRewardPool;  //available amount for paying rewards
    address public Treasury = 0x74682Fc32007aF0b6118F259cBe7bCCC21641600;
    bool public CS_frozen;  //Cold Staking frozen
    uint public staking_threshold = 0 ether;

    //uint public round_interval = 30 days;// 1 month
    //uint public max_delay = 365*2 days;  // 2 years 
    //uint public DateStartStaking = 1541894400;  // 11.11.2018 0:0:0 UTC


    //========== TESTING VALUES ===========
    uint public round_interval = 1 hours; // 1 hours
    uint public max_delay = 7 days; // 7 days
    uint public DateStartStaking;


    uint public eachBlockAdding = 12 ether; //autofill StakingRewardPool per block
    uint public StakingBalance;
    //========== end testing values ===================

    mapping(address => Staker) public staker;
    
    constructor () public {
        Timestamp = now;
    }
    
    function freeze(bool _f) public only_treasurer
    {
        CS_frozen = _f;
    }

    function withdraw_rewards () public only_treasurer
    {
        if (CS_frozen)
        {
            StakingRewardPool = address(this).balance.sub(TotalStakingAmount);
            Treasury.transfer(StakingRewardPool);
        }
    }

    function clear_treasurer () public only_treasurer
    {
        require(block.number > 1800000 && !CS_frozen);
        Treasury = 0x00;
    }
	

    function() public payable
    {
        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        // May not accept deposit from other contracts due GAS limit.
        start_staking();
    }

    // this function can be called for manualy update TotalStakingAmount value.
    function new_block() public
    {
        if (block.number > LastBlock)   //run once per block
        {
            uint _LastBlock = LastBlock;
            LastBlock = block.number;

            StakingRewardPool = address(this).balance.sub(TotalStakingAmount + msg.value);   //fix rewards pool for this block
            // msg.value here for case new_block() is calling from start_staking(), and msg.value will be added to CurrentBlockDeposits.

            //=========== debug only ==============
            if (_LastBlock == 0) _LastBlock = block.number - 1; //for first call
            StakingBalance = eachBlockAdding * (block.number - _LastBlock) + StakingBalance;   //simulate refill Staking Balance each block
            StakingRewardPool = StakingBalance.sub(TotalStakingAmount);   //fix rewards pool for this block
            //=========== end debug ===============
               

            //The consensus protocol enforces block timestamps are always atleast +1 from their parent, so a node cannot "lie into the past". 
            if (now > Timestamp) //But with this condition I feel safer :) May be removed.
            {
                uint _blocks = block.number - _LastBlock;
                uint _seconds = now - Timestamp;
                if (_seconds > _blocks * 25) //if time goes far in the future, then use new time as 25 second * blocks
                {
                    _seconds = _blocks * 25;
                }
                TotalStakingWeight += _seconds.mul(TotalStakingAmount);
                Timestamp += _seconds;
            }
        }
    }

    function start_staking() public staking_available payable
    {
        assert(msg.value >= staking_threshold);
        new_block(); //run once per block
        
        // claim reward if available
        if (staker[msg.sender].amount > 0)
        {
            if (Timestamp >= staker[msg.sender].time + round_interval)
            { 
                claim(); 
            }
            TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[msg.sender].time)).mul(staker[msg.sender].amount)); // remove from Weight        
        }

        TotalStakingAmount = TotalStakingAmount.add(msg.value);
        staker[msg.sender].time = Timestamp;
        staker[msg.sender].amount = staker[msg.sender].amount.add(msg.value);
       

        emit StartStaking(
            msg.sender,
            msg.value,
            staker[msg.sender].amount,
            staker[msg.sender].time
        );
    }


    function DEBUG_donation() public payable {

        emit DonationDeposited(msg.sender, msg.value);

    }

    function withdraw_stake() public only_staker
    {
        new_block(); //run once per block
        require(Timestamp >= staker[msg.sender].time + round_interval); //reject withdrawal before complete round

        uint _amount = staker[msg.sender].amount;
        // claim reward if available
        if (Timestamp >= staker[msg.sender].time + round_interval)
        { 
            claim(); 
        }
        TotalStakingAmount = TotalStakingAmount.sub(_amount);
        TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[msg.sender].time)).mul(staker[msg.sender].amount)); // remove from Weight
        
        staker[msg.sender].amount = 0;
        msg.sender.transfer(_amount);
        emit WithdrawStake(msg.sender, _amount);
    }

    //claim rewards
    function claim() public only_staker
    {
        if (CS_frozen) return; //Don't pay rewards when Cold Staking frozen

        new_block(); //run once per block
        uint _StakingInterval = Timestamp.sub(staker[msg.sender].time);  //time interval of deposit
        if (_StakingInterval >= round_interval)
        {
            uint _CompleteRoundsInterval = (_StakingInterval / round_interval).mul(round_interval); //only complete rounds
            uint _StakerWeight = _CompleteRoundsInterval.mul(staker[msg.sender].amount); //Weight of completed rounds
            uint _reward = StakingRewardPool.mul(_StakerWeight).div(TotalStakingWeight);  //StakingRewardPool * _StakerWeight/TotalStakingWeight

            StakingRewardPool = StakingRewardPool.sub(_reward);
            TotalStakingWeight = TotalStakingWeight.sub(_StakerWeight); // remove paid Weight

            staker[msg.sender].time = staker[msg.sender].time.add(_CompleteRoundsInterval); // reset to paid time, staking continue wthout lose uncomplete ruonds

            msg.sender.transfer(_reward);

            emit Claim(msg.sender, _reward);
        }
    }
   

    function reinvest() public only_staker
    {
        require(!CS_frozen);
        new_block(); //run once per block

        uint _StakingInterval = Timestamp.sub(staker[msg.sender].time);  //time interval of deposit
        if (_StakingInterval >= round_interval)
        {
            uint _StakerWeight = _StakingInterval.mul(staker[msg.sender].amount); //Staker weight
            uint _reward = StakingRewardPool.mul(_StakerWeight).div(TotalStakingWeight);  //StakingRewardPool * _StakerWeight/TotalStakingWeight

            StakingRewardPool = StakingRewardPool.sub(_reward);
            TotalStakingWeight = TotalStakingWeight.sub(_StakerWeight); // remove paid Weight

            staker[msg.sender].time = Timestamp; // reset to paid time to now
            staker[msg.sender].amount = staker[msg.sender].amount.add(_reward); //add reinvested amount
            TotalStakingAmount = TotalStakingAmount.add(_reward);

            emit StartStaking(
                msg.sender,
                _reward,
                staker[msg.sender].amount,
                staker[msg.sender].time
            );
        }
        
    }

    //This function may be used for info only. To show estimate user reward at current time.
    function stake_reward(address _addr) public constant returns (uint)
    {
        require(staker[_addr].amount > 0);
        require(!CS_frozen);

        uint _StakingInterval = now.sub(staker[_addr].time); //time interval of deposit

        uint _StakerWeight = _StakingInterval.mul(staker[_addr].amount); //Staker weight
        //uint _CompleteRoundsInterval = (_StakingInterval / round_interval).mul(round_interval); //only complete rounds
        //uint _StakerWeight = _CompleteRoundsInterval.mul(staker[_addr].amount); //Weight of completed rounds

        return StakingRewardPool.mul(_StakerWeight).div(TotalStakingWeight);    //StakingRewardPool * _StakerWeight/TotalStakingWeight
    }

    function staker_info(address _addr) public constant returns (uint _amount, uint _time)
    {
        _amount = staker[_addr].amount;
        _time = staker[_addr].time;
    }

    modifier only_staker
    {
        require(staker[msg.sender].amount > 0);
        _;
    }

    modifier staking_available
    {
        require(now >= DateStartStaking && !CS_frozen);
        _;
    }

    modifier only_treasurer
    {
        require(msg.sender == Treasury);
        _;
    }

    //return deposit to inactive staker
    function report_abuse(address _addr) public only_staker
    {
        require(staker[_addr].amount > 0);
        new_block(); //run once per block
        require(Timestamp > staker[_addr].time.add(max_delay));
        
        uint _amount = staker[_addr].amount;
        
        TotalStakingAmount = TotalStakingAmount.sub(_amount);
        TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[_addr].time)).mul(_amount)); // remove from Weight

        staker[_addr].amount = 0;
        _addr.transfer(_amount);
    }
}
