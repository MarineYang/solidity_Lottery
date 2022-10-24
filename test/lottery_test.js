const Lottery = artifacts.require("Lottery");
const { assert } = require('chai');
const assertRevert = require('./asserRevert');
const expectEvent = require('./expectEvent');

contract('Lottery', function([deployer, user1, user2]) {
    let lottery;
    let betAmount = 5 * 10 ** 15;
    let bet_block_interval = 3;
    beforeEach(async () => {
        lottery = await Lottery.new();
    })

    it('getPot should return current pot', async() => {
        let pot = await lottery.getPot();
        assert.equal(pot, 0);
    })

    describe('Bet', function() {
        it.only('should fail when bet money is not 0.005 ETH', async () => {
            // Fail 났을때 어떻게 하냐 ?!
            // openzeppeline solidity
            await assertRevert(lottery.bet('0xab', {from : user1, value:4000000000000000}));
            //
        })
        
        it.only('should put the bet to the bet queue with 1 bet', async () => {

            let receipt = await lottery.bet('0xab', {from : user1, value:betAmount})
            // console.log(receipt);

            let pot = await lottery.getPot();
            assert.equal(pot, 0 );

            let contractBalance = await web3.eth.getBalance(lottery.address);
            assert.equal(contractBalance, betAmount)
            let currentBlockNumber = await web3.eth.getBlockNumber();
            let bet = await lottery.getBetInfo(0);
            
            assert.equal(bet.answerBlockNumber, currentBlockNumber + bet_block_interval);
            assert.equal(bet.bettor, user1)
            assert.equal(bet.challenges, '0xab')


            await expectEvent.inLogs(receipt.logs, 'BET');
            // await expectEvent.inLogs(receipt.logs, 'WIN'); // 실패

        })
    })
    describe('Distribute', function() {
        describe('When the answer is checkable', function () {
            it('should give the user the pot when the answer matches', async () => {
                // 두 글자 다 맞았을 때
                // betAndDistrubute

                // await lottery.setAnswerforTest()
                // pot 머니의 변화량 확인
                // user의 balance 값을 확인.
                
            })
            it('should give the user the pot when the answer matches', async () => {
                // 한 글자만 맞았을 때
                
            })

            it('should give the user the pot when the answer matches', async () => {
                // 다 틀렸을 떄
                
            })
        })
        describe('When the answer is checkable', function () {
            
        })

        describe('When the answer is checkable', function () {
            
        })
        
    })
    describe.only('isMatch', function() {
        let blockHash = '0xab920efd7cab25b5f7c4b451060bfaeb975844c5cdc9cd29d17376d73c00dda8'

        it('should be BettingResult.Win when two characters match', async () => {
           
            let matchingResult = await lottery.isMatch('0xab', blockHash);

            assert.equal(matchingResult, 1);
        })

        it('should be BettingResult.Fail when two characters match', async () => {
            let matchingResult = await lottery.isMatch('0xcd', blockHash);

            assert.equal(matchingResult, 0);
        })

        it('should be BettingResult.Draw when two characters match', async () => {
            let matchingResult = await lottery.isMatch('0xaf', blockHash);
            assert.equal(matchingResult, 2);

            matchingResult = await lottery.isMatch('0xfb', blockHash);
            assert.equal(matchingResult, 2);
        })
    })
});