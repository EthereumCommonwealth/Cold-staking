// import ether from '../helpers/ether';
// import { advanceBlock } from '../helpers/advanceToBlock';
// import { increaseTimeTo, duration } from '../helpers/increaseTime';
// import latestTime from '../helpers/latestTime';
// import EVMRevert from '../helpers/EVMRevert';

// var web3 = require('web3');

var BigNumber = web3.BigNumber;//require('bignumber.js').BigNumber;

require('chai')
    .use(require('chai-as-promised'))
    .use(require('chai-bignumber')(BigNumber))
    .should();

const ColdStaking = artifacts.require('ColdStaking');

function ether(n) {
    return new BigNumber(web3.toWei(n, 'ether'));
}

contract('SampleCrowdsale', function (accounts) {

    const [owner, wallet, investor] = accounts;


    const _staking_threshold = new BigNumber(ether(0));

    const _staking_pool = new BigNumber(ether(0));

    const _max_delay = new BigNumber(42000);

    const _round_interval = new BigNumber(200);

    it('should deploy', async function () {
        const crowd = await ColdStaking.new();

        const staking_threshold = await crowd.staking_threshold();

        staking_threshold.should.be.bignumber.equal(_staking_threshold);

        const staking_pool = await crowd.staking_pool();

        staking_pool.should.be.bignumber.equal(_staking_pool);

        const reward = await crowd.reward();

        reward.should.be.bignumber.equal(0);

        const max_delay = await crowd.max_delay();

        max_delay.should.be.bignumber.equal(_max_delay);

        const round_interval = await crowd.round_interval();

        round_interval.should.be.bignumber.equal(_round_interval);


    });

    it('should accept donation, increase balance and reward', async function () {

        const crowd = await ColdStaking.new({from: owner});

        const donation = await crowd.First_Stake_donation({value: ether(1)});

        const staking_pool = await crowd.staking_pool();

        const reward_ = await crowd.reward();

        reward_.should.be.bignumber.equal(ether(1));

        staking_pool.should.be.bignumber.equal(ether(0))
    });

    it('should start_staking', async function () {

        const crowd = await ColdStaking.new({from: owner});

        const _value = ether(1);

        const startStaking = await crowd.start_staking({value: _value, from: owner});

        const crowdBal = web3.eth.getBalance(crowd.address);

        crowdBal.should.be.bignumber.equal(_value);

        startStaking.logs[0].event.should.be.equal('StartStaking');

        const staking_pool = await crowd.staking_pool();

        staking_pool.should.be.bignumber.equal(_value);


        const stakingInfo = await crowd.staker_info(owner);

        const [weight, init, stake_time, reward] = stakingInfo;

        // stakingInfo.forEach(i => console.log(i.toNumber()))

        weight.should.be.bignumber.equal(_value);


    });

})

