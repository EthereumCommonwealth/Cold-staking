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

    uint LastBlock;
    uint Timestamp;
    uint CurrentBlockDeposits;      //sum of all Deposits in current block
    uint CurrentBlockWithdrawals;   //sum of all Withdrawals in current block
    uint TotalStakingWeight;        //total weight = sum (each_staking_amount * each_staking_time)
    uint public TotalStakingAmount; //currently frozen amount for Staking
    uint public StakingRewardPool;  //available amount for paying rewards


    uint public staking_threshold = 0 ether;

    //uint public round_interval = 30 days;// 1 month
    //uint public max_delay = 365 days;  // 1 year 
    //uint public DateStartStaking = 1541894400;  // 11.11.2018 0:0:0 UTC
    //uint public FixingPeriod = 1 days; // pariod to fix StakingRewardPool and TotalStakingWeight. At this period order of transaction does not effect on reward amount.


    //========== TESTING VALUES ===========
    uint public round_interval = 4 hours; // 4 hours
    uint public max_delay = 7 days; // 7 days
    uint public DateStartStaking;
    uint public FixingPeriod = 15 minutes; // pariod to fix StakingRewardPool and TotalStakingWeight. At this period order of transaction does not effect on reward amount.


    uint eachBlockAdding = 120 ether; //autofill StakingRewardPool per block
    uint StakingBalance;
    address owner = 0x4ecaDF290630Eb76550118032202BEd69d44b2C7;

    /*
    constructor () public payable {
        owner = msg.sender;
    }
    */
    function kill() public
    {
        require(msg.sender == owner);
        selfdestruct(owner);
    }
    //========== end testing values ===================

    mapping(address => Staker) staker;


    function() public payable
    {
        // No donations accepted to fallback!
        // Consider value deposit is an attempt to become staker.
        start_staking();
    }

    function new_block() private
    {
        if (block.number > LastBlock)   //run once per block
        {
            TotalStakingAmount = TotalStakingAmount.add(CurrentBlockDeposits).sub(CurrentBlockWithdrawals);
            CurrentBlockDeposits = 0;
            CurrentBlockWithdrawals = 0;
            if ((now / FixingPeriod) > (Timestamp / FixingPeriod))   //new period begin
            {
               StakingRewardPool = address(this).balance.sub(TotalStakingAmount + msg.value);   //fix rewards pool for FixingPeriod
               // msg.value here for case new_block() is calling from start_staking(), and msg.value will be added to CurrentBlockDeposits.

               //=========== debug only ==============
               StakingBalance = eachBlockAdding * (block.number - LastBlock) + StakingBalance;   //simulate refill Staking Balance each block
               StakingRewardPool = StakingBalance.sub(TotalStakingAmount);   //fix rewards pool for FixingPeriod
               //=========== end debug ===============
               
            }

            //The consensus protocol enforces block timestamps are always atleast +1 from their parent, so a node cannot "lie into the past". 
            if (now > Timestamp) //But with this condition I feel safer :) May be removed.
            {
                TotalStakingWeight += (now - Timestamp).mul(TotalStakingAmount);
                Timestamp = now;
            }
            LastBlock = block.number;
        }
    }

    function start_staking() public staking_available payable
    {
        assert(msg.value >= staking_threshold);
        new_block(); //run once per block
        
        // claim reward if available
        if (staker[msg.sender].amount > 0 && Timestamp >= staker[msg.sender].time + round_interval)
        {
            claim();
        }

        CurrentBlockDeposits = CurrentBlockDeposits.add(msg.value);
        staker[msg.sender].amount = staker[msg.sender].amount.add(msg.value);
        staker[msg.sender].time = Timestamp;
        //staker[msg.sender].init_block = block.number;
       

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

    function claim_and_withdraw() public
    {
        claim();
        withdraw_stake();
    }

    function withdraw_stake() public only_staker
    {
        new_block(); //run once per block
        //require(Timestamp >= staker[msg.sender].time + round_interval); //reject withdrawal before complete round

        uint _amount = staker[msg.sender].amount;
        CurrentBlockWithdrawals = CurrentBlockWithdrawals.add(_amount);
        TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[msg.sender].time)).mul(staker[msg.sender].amount)); // remove from Weight
        
        staker[msg.sender].amount = 0;
        msg.sender.transfer(_amount);
        emit WithdrawStake(msg.sender, _amount);
    }

    function claim() public only_staker
    {
        new_block(); //run once per block
        uint _time = Timestamp.sub(staker[msg.sender].time);  //time interval of deposit
        if (_time >= round_interval)
        {
            _time = (_time / round_interval).mul(round_interval); //only complete rounds
            uint _reward = StakingRewardPool.mul(_time.mul(staker[msg.sender].amount)).div(TotalStakingWeight);

            StakingRewardPool = StakingRewardPool.sub(_reward);

            TotalStakingWeight = TotalStakingWeight.sub(_time.mul(staker[msg.sender].amount)); // remove paid Weight
            staker[msg.sender].time = staker[msg.sender].time.add(_time); // reset to paid time, staking continue wthout lose uncomplete ruonds

            //TotalStakingWeight = TotalStakingWeight.sub((Timestamp.sub(staker[msg.sender].time)).mul(staker[msg.sender].amount)); // remove paid Weight
            //staker[msg.sender].time = Timestamp;  // reset start staking time to 'now'.

            msg.sender.transfer(_reward);

            emit Claim(msg.sender, _reward);
        }
    }

    //This function may be used for info only. To show estimate user reward at current time.
    function stake_reward(address _addr) public constant returns (uint)
    {
        require(staker[_addr].amount > 0);
        uint _time = now.sub(staker[_addr].time); //time interval of deposit
        //_time = (_time / round_interval).mul(round_interval); //only complete rounds

        return StakingRewardPool.mul(_time.mul(staker[_addr].amount)).div(TotalStakingWeight);
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
        require(now >= DateStartStaking);
        _;
    }

    // why we need this function?
    function report_abuse(address _addr) public only_staker
    {
        require(staker[_addr].amount > 0);
        require(now > staker[_addr].time.add(max_delay));
        uint _amount = staker[_addr].amount;
        staker[_addr].amount = 0;
        _addr.transfer(_amount);
    }
}
