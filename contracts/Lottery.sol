pragma solidity >=0.4.22 <0.9.0;

contract Lottery {
     struct BetInfo {
        uint256 answerBlockNumber;
        address payable bettor;
        byte challenges;
    }

    uint256 private _tail;
    uint256 private _head;  // 결과를 검증할 때 0번 헤드부터 값을 뽑아옴.

    mapping (uint256 => BetInfo) private _bets;
    address payable public owner;

    uint256 constant internal BET_AMOUNT = 5 * 10 ** 15;
    uint256 constant internal BET_BLOCK_INTERVAL = 3;
    uint256 constant internal BLOCK_LIMIT = 256;
    uint256 private _pot;

    bool private mode = false; // false : test mode, true : use real block hash
    bytes32 public ansForTest;
    enum BlockStatus{Checkable, NotReveabled, BlockLimitPassed}
    enum BettingResult{Fail, Win, Draw}
    
    event BET(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);

    event WIN(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event FAIL(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event DRAW(uint256 index, address bettor, uint256 amount, byte challenges, byte answer, uint256 answerBlockNumber);
    event REFUND(uint256 index, address bettor, uint256 amount, byte challenges, uint256 answerBlockNumber);

    constructor() public {
        owner = msg.sender;
    }

    function getPot() public view returns (uint256 pot) {
        return _pot;
    }

    /**
     * @dev 배팅과 동시에 정답 체크를 한다.
     * @param challenges 유저가 베팅하는 글자
     * @return 함수가 잘 수행되었는지 확인해는 bool 값
     */
    function betAndDistribute(byte challenges) public payable returns (bool result) {
        bet(challenges);
        
        distribute();

        return true;
    }
    // 배팅을 하고 결과값을 검증 해야함.
    // 1. Bet
        // Save the Bet to the Queue

    // 2. Distribute
        // check the answer
        // 값이 틀리면 팟머니를 돌려줘야함.

    /**
     * @dev 베팅을 한다. 유저는 0.005 ETH를 보내야 하고, 베팅용 1 byte 글자를 보낸다.
     * 큐에 저장된 베팅 정보는 이후 distribute 함수에서 해결된다.
     * @param challenges 유저가 베팅하는 글자
     * @return 함수가 잘 수행되었는지 확인해는 bool 값
     */
    function bet(byte challenges) public payable returns (bool result) {

        require(msg.value == BET_AMOUNT, "Not enough ETH");

        require(pushBet(challenges), "Fail to add BetInfo");

        // 375 gas ===> 5000 gas
        emit BET(_tail - 1, msg.sender, msg.value, challenges, block.number + BET_BLOCK_INTERVAL);
        return true;
    }

    // Distribute
    /**
     * @dev 배팅 결과값을 확인 하고 팟머니를 분배한다.
     * 정답 실패 : 팟머니 축적, 정답맞춤 : 팟머니 획득, 한글자 맞춤 or 정답 확인 불가 : 베팅 금액만 획득
     */
    function distribute() public {
        // 큐에 저장된 배팅 정보
        // head 3 4 5 6 7 8 9 10 11 12 tail
        // 큐에 팝 푸쉬 쭉쭉 해주다가 정답을 확인 할 수 없을 때 멈춤.
        // 루프 설계해야함.

        uint256 cur;
        uint256 transferAmount;
        BetInfo memory b;
        BlockStatus currentBlockStatus;
        BettingResult currentBettingResult;
        for (cur=_head; cur < _tail; cur++) {
            // 블록이 체크가 불가능한 상태일 때 .
            // 블록이 제한이 지났을 떄 : block.number >= AnswerBlockNumber + BLOCK_LIMIT
            // 체크가 되었을 때 : block.number > AnswerBlockNumber && block.number < BLOCK_LIMIT + AnswerBlockNumber
            b = _bets[cur];
            currentBlockStatus = getBlockStatus(b.answerBlockNumber);

            if (currentBlockStatus == BlockStatus.Checkable) {
                // if win, bettor gets pot money
                // if fail, bettor's money goes pot
                // if draw, refound bettor's money 
                bytes32 answerBlockHash = getAnswerBlockHash(b.answerBlockNumber);
                currentBettingResult = isMatch(b.challenges, getAnswerBlockHash(b.answerBlockNumber));

                if (currentBettingResult == BettingResult.Win) {
                    // transfer pot
                    transferAmount = transferAfterPayingFee(b.bettor, _pot + BET_AMOUNT);
                    // pot = 0
                    _pot = 0;
                    // emit WIN
                    emit WIN(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                if (currentBettingResult == BettingResult.Fail) {
                    // pot = pot + BET_AMOUNT
                    _pot += BET_AMOUNT;

                    // emit FAIL
                    emit FAIL(cur, b.bettor, 0, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }
                if (currentBettingResult == BettingResult.Draw) {
                    // transfer only BET_AMOUNT
                    transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                    
                    // emit DRAW
                    emit DRAW(cur, b.bettor, transferAmount, b.challenges, answerBlockHash[0], b.answerBlockNumber);
                }

            }
            if (currentBlockStatus == BlockStatus.NotReveabled) {
                break;
            }
            if (currentBlockStatus == BlockStatus.BlockLimitPassed) {
                // refund
                transferAmount = transferAfterPayingFee(b.bettor, BET_AMOUNT);
                // emit refund
                emit REFUND(cur, b.bettor, transferAmount, b.challenges, b.answerBlockNumber);
            }
            popBet(cur);
        }
        _head = cur;
    }

    function transferAfterPayingFee(address payable addr, uint256 amount) internal returns (uint256) {
        // 수수료를 컨트랙 주인에게 조금 떼어 주자.
        // uint256 fee = amount / 100; // 1%
        uint256 fee = 0;
        uint256 amountWithoutfee = amount - fee;

        // transfer to addr
        addr.transfer(amountWithoutfee);
        
        // transfer to owner 
        owner.transfer(fee);

    }

    function setAnswerBlockHash(bytes32 answer) public returns (bool result) {
        require(msg.sender == owner, "Only owner can set the answer for test mode . ");
        ansForTest = answer;
        return true;
    }

    function getAnswerBlockHash(uint256 answerBlockNumber) internal view returns (bytes32 answer) {
        return mode ? blockhash(answerBlockNumber) : ansForTest;
    }
    /**
     * @dev 배팅 글자와 정답을 확인함
     * @param challenges 배팅 글자
     * @param answer     정답자
     */
    function isMatch(byte challenges, bytes32 answer) public pure returns (BettingResult) {
        // challenges 0xab
        // answer 0xab.....ff 32 bytes
        byte c1 = challenges;
        byte c2 = challenges;
        byte a1 = answer[0];
        byte a2 = answer[0];


        c1 = c1 >> 4;   // 0xab -> 0x0a
        c1 = c1 << 4;   // 0x0a -> 0xa0

        a1 = a1 >> 4;
        a1 = a1 << 4;

        c2 = c2 << 4;
        c2 = c2 >> 4;

        a2 = a2 << 4;
        a2 = a2 >> 4;

        if(a1 == c1 && a2 == c2) {
            return BettingResult.Win;
        }
        if (a1 == c1 || a2 == c2) {
            return BettingResult.Draw;
        }
        return BettingResult.Fail;
    }
    function getBlockStatus(uint256 answerBlockNumber) internal returns (BlockStatus) {
        if (block.number > answerBlockNumber && block.number < BLOCK_LIMIT + answerBlockNumber) {
            return BlockStatus.Checkable;
        }
        if (block.number <= answerBlockNumber) {
            return BlockStatus.NotReveabled;
        }
        if (block.number >= answerBlockNumber + BLOCK_LIMIT) {
            return BlockStatus.BlockLimitPassed;
        }

        return BlockStatus.BlockLimitPassed;
        
    }
    function getBetInfo(uint256 index) public view returns(uint256 answerBlockNumber, address bettor, byte challenges) {
        BetInfo memory b = _bets[index];
        answerBlockNumber = b.answerBlockNumber;
        bettor = b.bettor;
        challenges = b.challenges;
    }

    function pushBet(byte challenges) public returns (bool) {
        BetInfo memory b;
        b.bettor = msg.sender;  // 20 byte
        b.answerBlockNumber = block.number + BET_BLOCK_INTERVAL; // 32byte  20000 gas
        b.challenges = challenges;  // byte // 20000 gas

        _bets[_tail] = b;
        _tail++; // 32byte 값 변화 // 20000 gas => 5000 gas

        return true;
    }

    function popBet(uint256 index) internal returns (bool) {
        delete _bets[index];
        return true;
    }
}