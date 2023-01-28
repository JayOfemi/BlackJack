// SPDX-License-Identifier: MIT

pragma solidity >=0.8.12 <0.9.0;

// BlackJack.sol
// Jay Ofemi
// BlackJack smart contract
// Created: 06/23/2018
// Revised: 12/17/2022

//////////////////////////////////
// RULES:
//////////////////////////////////
// * Player can either double down or split, player cannot split then double down and vice versa.
// * Player cannot split then split again or double down twice.
// * Player who splits Aces can receive only one more additional card on a hand.
// * Dealer must Hit on and up to 16 and Stand on 17.
// * Aces are high unless card total is already greater than 11.
// * Blackjack payout is 3:2
// * No surrender.
///////////////////////////////////

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


/**
 * @title BlackJack
 * @dev Smart contract game of Blackjack that can be deployed on the blockchain.
 */
contract BlackJack {
    using SafeMath for uint256;

    struct Game {

        uint256 Id;
        address Player;
        
        uint256 SafeBalance;
        uint256 OriginalBalance;
        uint256 SplitCounter;
        uint256 GamesPlayed;

        uint256 PlayerBet;
        uint256 InsuranceBet;
        uint256 PlayerCard1;
        uint256 PlayerCard2;
        uint256 PlayerNewCard;
        uint256 PlayerCardTotal;
        uint256 PlayerSplitTotal;

        uint256 DealerCard1;
        uint256 DealerCard2;
        uint256 DealerNewCard;
        uint256 DealerCardTotal;

        bool CanDoubleDown;
        bool CanInsure;
        bool CanSplit;
        bool IsSplitting;
        bool IsSoftHand;

        bool IsRoundInProgress;
        
        string DealerMsg;
    }

    uint256 constant private _ethDepositLowLimit = 1000 gwei;
    uint256 constant private _ethDepositHighLimit = 10 ether;

    uint256 constant private _ethBetLowLimit = 100 gwei;
    uint256 constant private _ethBetHighLimit = 1 ether; // 1000000000000000000 wei

    uint256 private _rngCounter;

    uint256 private _indexCounter;

    address immutable private _owner;

    mapping(address => uint256) private _currentPlayersToGameIdMap;
    mapping(uint256 => Game) private _idsToGameMap;

    /////////////////////////////////////////////////////////////////

    // ERROR LOG GLOSSARY:
    // * INV = Invalid. 
    // * DNE = Does Not Exist.
    // * CCF = Cannot Call Function.
    // * INS_Funds = Insufficient Funds.
    // * x_Only = Only x can call function.
    // * Deposit_Limit = Ether deposit limit not reached or passed.
    // * Bet_Limit = Ether bet limit not reached or passed.

    //////////////////////////////////////////////////////////////////

    
    /**
     * @dev Event Logging
     */
    event StartNewGameEvent(uint256 indexed GameId, address indexed Player, uint256 indexed Amount);
    event CashOutEvent(uint256 indexed GameId, address indexed Player, uint256 indexed Amount);
    event BeforeValueTransferEvent(uint256 indexed GameId, address indexed Player, uint256 indexed Amount);
    event AfterValueTransferEvent(address indexed Player);
    
    /**
     * @dev Modifiers
     */
    modifier IsValidAddr() {
        require(msg.sender != address(0x0), "Address_INV");
        _;
    }
    
    /**
     * @dev Constructor
     */
    constructor () {
        
        _rngCounter = 1;
        _indexCounter = 1;

        _owner = msg.sender;
    }
    
    /**
     * @dev Fallback
     */
    fallback () IsValidAddr external {
        revert("Function_DNE.");
    }

    /**
     * @dev Recieve
     */
    receive () IsValidAddr external payable {
        // Players must use StartNewGame function to pay
        revert("Please use StartNewGame Function to pay contract.");
    }
    
    /**
     * @dev StartNewGame - Starts a new game with msg.sender's address registered as player.
     */
    function StartNewGame() external payable {
        
        require(_currentPlayersToGameIdMap[msg.sender] == 0, "ExistingPlayer_CCF"); // Players in an existing game cannot start a new game
        require(msg.value > _ethDepositLowLimit && msg.value <= _ethDepositHighLimit, "Deposit_Limit"); // Ensure deposit is within Limits

        Game memory game;

        game.Id = _indexCounter;

        game.SafeBalance += msg.value;
        game.OriginalBalance += msg.value;
        
        game.Player = msg.sender;
        
        game.DealerMsg = "Contract Paid.";

        _indexCounter++;

        _idsToGameMap[game.Id] = game;
        _currentPlayersToGameIdMap[msg.sender] = game.Id;

        emit StartNewGameEvent(game.Id, game.Player, game.OriginalBalance);
    }
    
    /**
     * @dev PlaceBet - Begins a new game round.
     * @param bet Amount to bet to start a new round 100 GWei < bet < 1 Ether.
     */
    function PlaceBet(uint256 bet) IsValidAddr public {

        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];

        require(!game.IsRoundInProgress, "IsNewRound_Only");
        require(bet >= _ethBetLowLimit && bet <= _ethBetHighLimit, "Bet_Limit"); // Ensure bet is within limits
        require(bet > 0 && bet <= game.SafeBalance, "INS_Funds"); // Ensure player can afford bet
        
        game.SafeBalance -= bet; // Update balance: remove bet
        
        if(game.CanDoubleDown || game.CanSplit) {
            game.PlayerBet += bet;
        } else {
            game.PlayerBet = bet;
        }
        
        game.IsRoundInProgress = true; // Start round
        
        game.GamesPlayed++; // Update game counter
        
        // Only deal cards if this is not a Double Down, Split or Insurance bet
        if(game.CanDoubleDown || game.CanSplit) {
            game.DealerMsg = "Bet Placed.";
        } else {

           DealCards(game);
        }
    }
    
    /**
     * @dev DealCards
     * @param game Ongoing game to store game state after dealing cards.
     */
    function DealCards(Game storage game) private {
        
        // Clear any previous hands
        game.PlayerCard1 = 0;
        game.PlayerCard2 = 0;
        game.PlayerNewCard = 0;
        game.PlayerCardTotal = 0;
        game.PlayerSplitTotal = 0;
        game.DealerCard1 = 0;
        game.DealerCard2 = 0;
        game.DealerNewCard = 0;
        game.DealerCardTotal = 0;
        game.SplitCounter = 0;
        game.InsuranceBet = 0;
        game.IsSoftHand = false;
        
        // Player draws card 1
        game.PlayerCard1 = GetCard();
        if(game.PlayerCard1 == 1) {
            game.PlayerCard1 = 11; // Ace
            game.IsSoftHand = true;
        }
        
        // Dealer draws card 1
        game.DealerCard1 = GetCard();
        
        // Player draws card 2
        game.PlayerCard2 = GetCard();
        if(game.PlayerCard2 == 1 && game.PlayerCard1 < 11) {
            game.PlayerCard2 = 11; // Ace
            game.IsSoftHand = true;
        }
        
        // Player card total
        game.PlayerCardTotal = game.PlayerCard1 + game.PlayerCard2;
        
        // Offer insurance
        if(game.DealerCard1 == 1) {
            game.DealerCard1 = 11;
            game.CanInsure = true;
        }
        
        // Dealer's total
        game.DealerCardTotal = game.DealerCard1 + game.DealerCard2;
        
        // BlackJack - Natural
        if(game.PlayerCardTotal == 21) {
            // There might be a standoff
            if(game.DealerCard1 == 10) {
                // Draw dealer's second card
                game.DealerCard2 = GetCard();
                // Ace is always 11 in this case
                if(game.DealerCard2 == 1) 
                    game.DealerCard2 = 11;
                
                game.DealerCardTotal = game.DealerCard1 + game.DealerCard2;
            }
            
            // Choose winner
            if(game.DealerCardTotal == game.PlayerCardTotal) {
                game.DealerMsg = "StandOff!";
                game.SafeBalance += game.PlayerBet; // Update balance: bet
            } else {
                game.DealerMsg = "BlackJack! Player Wins.";
                game.SafeBalance += ((game.PlayerBet * 2) + (game.PlayerBet / 2)); //update balance: bet * 2.5 = original bet * 2 + bet * 0.5
            }

            game.IsRoundInProgress = false;
        } else {
            // Normal turn
            if(game.CanInsure) {
                game.DealerMsg = "Player's Turn. Want Insurance?";
            } else {
                game.DealerMsg = "Player's Turn.";
            }
        }
        
        // Split
        if(game.PlayerCard1 == game.PlayerCard2) {
            if(game.CanInsure)
                game.DealerMsg = "Player's Turn. Want Insurance? Player can Split.";
            else
                game.DealerMsg = "Player's Turn. Player can Split.";
            
            game.CanSplit = true;
        }
        
        // Double down - 9 or 10 or 11
        if(game.PlayerCardTotal == 9 || game.PlayerCardTotal == 10 || game.PlayerCardTotal == 11) {
            if(game.CanInsure) {
                game.DealerMsg = "Player's Turn. Want Insurance? Player can Double Down.";
                if(game.CanSplit)
                    game.DealerMsg = "Player's Turn. Want Insurance? Player can Split or Double Down.";
            } else {
                game.DealerMsg = "Player's Turn. Player can Double Down.";
                if(game.CanSplit)
                    game.DealerMsg = "Player's Turn. Player can Split or Double Down.";
            }
            game.CanDoubleDown = true;
        }
    }
    
    /**
     * @dev Hit - Can only be called by player in an ongoing game.
     */
    function Hit() IsValidAddr external {
        
        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(game.IsRoundInProgress, "OnPlayerTurn_Only");

        game.CanDoubleDown = false; // Remove chance to double
        game.CanSplit = false; // Remove chance to split
        game.CanInsure = false; // Remove Insurance chance
        
        game.PlayerNewCard = GetCard();

        if(game.PlayerNewCard == 1 && game.PlayerCardTotal < 11) {
            // Ace is 1 unless Player has a total less than 11
            game.PlayerNewCard = 11;
            game.IsSoftHand = true;
        }   
        
        if(game.IsSplitting) {
            // Update split total on 1st round during split
            game.DealerMsg = "Player's Turn.";
            game.PlayerSplitTotal += game.PlayerNewCard;

            if(game.IsSoftHand && game.PlayerSplitTotal > 21) {
                game.PlayerSplitTotal -= 10;
                game.IsSoftHand = false;
            }
            
            if(game.PlayerSplitTotal > 21) {
                game.DealerMsg = "Split hand complete. Player's Turn.";
                game.SplitCounter++;
                game.IsSplitting = false; 
            }
        } else {
            // Choose winner for normal play or second round during split
            game.PlayerCardTotal += game.PlayerNewCard;

            if(game.IsSoftHand && game.PlayerCardTotal > 21){
                game.PlayerCardTotal -= 10;
                game.IsSoftHand = false;
            }

            CheckWinnerOnHit();
        }
    }
    
    
    /**
     * @dev Stand - Can only be called by player in an ongoing game.
     */
    function Stand() IsValidAddr public {
        
        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(game.IsRoundInProgress, "OnPlayerTurn_Only");
        
         game.CanDoubleDown = false; // Remove chance to double
        game.CanSplit = false; // Remove chance to split
        game.CanInsure = false; // Remove Insurance chance

        if(!game.IsSplitting) {
            PlayDealerHand();
        } else {
            game.DealerMsg = "Split hand complete. Player's Turn.";
            game.SplitCounter++;
            game.IsSplitting = false;
        }
    }

    /**
     * @dev PlayDealerHand
     */
    function PlayDealerHand() private {

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];

        // Show Dealer Card 2
        game.DealerCard2 = GetCard();
        if(game.DealerCard2 == 1 && game.DealerCard1 < 11)
            game.DealerCard2 = 11; // Ace
        
        // Update Dealer's card Total
        game.DealerCardTotal = game.DealerCard1 + game.DealerCard2;       
        
        // Dealer must Stand on all 17s
        while(game.DealerCardTotal < 17) {

            game.DealerNewCard = GetCard();
            if(game.DealerNewCard == 1 && game.DealerCardTotal < 11)
                game.DealerNewCard = 11; // Ace
            
            game.DealerCardTotal += game.DealerNewCard;
        }

        CheckWinnerOnStand();
    }
    
    /**
     * @dev DoubleDown - Can only be called by player in an ongoing game.
     */
    function DoubleDown() IsValidAddr external {
        
        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(game.IsRoundInProgress, "OnPlayerTurn_Only");
        require(game.CanDoubleDown, "OnCanDoubleDownTurn_Only");
        
        game.CanSplit = false; // Remove chance to split
        game.CanInsure = false; // Remove Insurance chance
        
        game.IsRoundInProgress = false; // Pause game to place Bet
        
        PlaceBet(game.PlayerBet); // Place same amount as original Bet and resume game

        game.CanDoubleDown = false;
        
        game.PlayerNewCard = GetCard(); // Deal extra card
        if(game.PlayerNewCard == 1 && game.PlayerCardTotal < 11) {
            game.PlayerNewCard = 11; // Ace
            game.IsSoftHand = true;
        }
        
        game.PlayerCardTotal += game.PlayerNewCard;
        
        // Let dealer finish hand and end round
        PlayDealerHand();
    }
    
    
    /**
     * @dev Split - Can only be called by player in an ongoing game.
     */
    function Split() IsValidAddr external {
        
        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(game.IsRoundInProgress, "OnPlayerTurn_Only");
        require(game.CanSplit, "OnCanSplitTurn_Only");
        
        game.CanDoubleDown = false; // Remove chance to double
        game.CanInsure = false; // Remove Insurance chance
        
        if(game.PlayerCard1 == 11) {
            game.PlayerCardTotal = 11;
            game.PlayerSplitTotal = 11;
        } else {
            game.PlayerCardTotal = game.PlayerCardTotal/2;
            game.PlayerSplitTotal = game.PlayerCardTotal;
        }

        game.SplitCounter = 0;
        game.IsSplitting = true;
        
        game.IsRoundInProgress = false; // Pause game to place bet
        
        PlaceBet(game.PlayerBet); // Place same amount as original bet and resume game. This doubles the current playerbet, so split bet is now bet * 0.5.
        
        game.CanSplit = false;
        
        // Player's cards are both Aces
        if(game.PlayerCard1 == 11) {
            game.PlayerNewCard = GetCard(); // Deal only one more card for PlayerCard1. Ace is always 1 in this case
            game.PlayerSplitTotal += game.PlayerNewCard;

            game.PlayerNewCard = GetCard(); // Deal only one more card for PlayerCard2. Ace is always 1 in this case
            game.PlayerCardTotal += game.PlayerNewCard;
            
            game.IsSplitting = false;
            
            PlayDealerHand();
        }
    }
    
    
    /**
     * @dev Insurance - Can only be called by player in an ongoing game.
     */
    function Insurance() IsValidAddr external {

        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(game.IsRoundInProgress, "OnPlayerTurn_Only");
        require(game.CanInsure, "OnCanInsureTurn_Only");
        
        game.InsuranceBet = game.PlayerBet / 2;

        require(game.InsuranceBet > 0 && game.InsuranceBet <= game.SafeBalance, "INS_Funds"); // Ensure player can afford insurance bet

        game.SafeBalance -= game.InsuranceBet; // Update balance: remove insurance bet
        
        game.DealerMsg = "Player's Turn.";

        game.CanInsure = false;
        
    }
    
    
    /**
     * @dev CheckWinnerOnHit
     */
    function CheckWinnerOnHit() private {

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        
        if(game.PlayerCardTotal > 21) { // Bust
            game.DealerMsg = "Player Bust.";

            if(game.InsuranceBet != 0) {
                game.DealerCard2 = GetCard();
                game.DealerCardTotal += game.DealerCard2;
                
                if(game.DealerCardTotal == 21)
                    game.SafeBalance += (game.InsuranceBet * 2); // Update balance: insurance bet * 2
            }

            if(game.SplitCounter == 1) {
                PlayDealerHand();
            } else
                game.IsRoundInProgress = false;

        } else {
            game.DealerMsg = "Player's Turn.";
        }
    }

    /**
     * @dev CheckWinnerOnStand
     */
    function CheckWinnerOnStand() private {

        Game storage game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        
        if(game.DealerCardTotal > 21) {
            game.DealerMsg = "Dealer Bust.";
            game.IsRoundInProgress = false;

            if(game.SplitCounter == 1) { // split hand
                if(game.PlayerCardTotal <= 21) {
                    game.DealerMsg = "Dealer Bust. Player Wins.";
                    game.SafeBalance += game.PlayerBet; // Update balance: split bet * 2 = bet    
                }
                
                if(game.PlayerSplitTotal <= 21) {
                    game.DealerMsg = string.concat(game.DealerMsg, " Player won split hand.");
                    game.SafeBalance += game.PlayerBet; // Update balance: split bet * 2 = bet    
                } else {
                    game.DealerMsg = string.concat(game.DealerMsg, " Player lost split hand.");
                }
            } else { // Normal hand
                game.DealerMsg = "Dealer Bust. Player Wins.";
                game.SafeBalance += (game.PlayerBet * 2); // Update balance: bet * 2
            }

        } else if(game.DealerCardTotal == 21) {

            game.DealerMsg = "Dealer Wins.";
            game.IsRoundInProgress = false;

            if(game.InsuranceBet != 0)
                game.SafeBalance += (game.InsuranceBet * 2); // Update balance: insurance bet * 2

            if(game.PlayerCardTotal == 21) { // Standoff
                game.DealerMsg = "StandOff!";
                
                if(game.SplitCounter == 1)
                    game.SafeBalance += (game.PlayerBet / 2); // Update balance: split bet = bet * 0.5
                else
                    game.SafeBalance += (game.PlayerBet); // Update balance: bet
            }

            if(game.SplitCounter == 1) {
                if(game.PlayerSplitTotal == 21) {
                    game.DealerMsg = string.concat(game.DealerMsg, " StandOff on split hand!");
                    game.SafeBalance += (game.PlayerBet / 2); // Update balance: split bet = bet * 0.5
                } else {
                    game.DealerMsg = string.concat(game.DealerMsg, " Player lost split hand.");
                }
            }

        } else { // game.DealerCardTotal < 21

            if(game.PlayerCardTotal < 21 && (21 - game.DealerCardTotal) == (21 - game.PlayerCardTotal)) { // Standoff
                game.DealerMsg = "StandOff!";
                game.IsRoundInProgress = false;

                if(game.SplitCounter == 1)
                    game.SafeBalance += (game.PlayerBet / 2); // Update balance: split bet = bet * 0.5
                else
                    game.SafeBalance += game.PlayerBet; // Update balance: bet
            } else if(game.PlayerCardTotal > 21 || (21 - game.DealerCardTotal) < (21 - game.PlayerCardTotal)) {
                game.DealerMsg = "Dealer Wins.";
                game.IsRoundInProgress = false;
            } else {
                game.DealerMsg = "Player Wins.";
                game.IsRoundInProgress = false;

                if(game.SplitCounter == 1)
                    game.SafeBalance += game.PlayerBet; // Update balance: split bet * 2 = bet
                else
                    game.SafeBalance += (game.PlayerBet * 2); // Update balance: bet * 2
            }

            if(game.SplitCounter == 1) {
                if(game.PlayerSplitTotal < 21 && (21 - game.DealerCardTotal) == (21 - game.PlayerSplitTotal)) { // Split hand: Standoff
                    game.DealerMsg = string.concat(game.DealerMsg, " StandOff on split hand!");
                    game.IsRoundInProgress = false;

                    game.SafeBalance += (game.PlayerBet / 2); // Update balance: split bet = bet * 0.5
                } else if(game.PlayerSplitTotal > 21 || (21 - game.DealerCardTotal) < (21 - game.PlayerSplitTotal)) {
                    game.DealerMsg = string.concat(game.DealerMsg, " Player lost split hand.");
                    game.IsRoundInProgress = false;
                } else {
                    game.DealerMsg = string.concat(game.DealerMsg, " Player won split hand.");
                    game.IsRoundInProgress = false;

                    game.SafeBalance += game.PlayerBet; // Update balance: split bet * 2 = bet    
                }
            }
        }
    }

    /**
     * @dev CashOut - Can only be called by player before or after a game round.
     */
    function CashOut() IsValidAddr external {
        
        require(_currentPlayersToGameIdMap[msg.sender] != 0, "Game_DNE");

        Game memory game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        require(!game.IsRoundInProgress, "IsNewRound_Only");
        
        uint256 tempBalance = game.SafeBalance;
        if(address(this).balance >= 0 && address(this).balance < game.SafeBalance) {
            tempBalance = address(this).balance;
        }

        assert(address(this).balance >= tempBalance);
        
        BeforeValueTransfer(msg.sender);

        payable(msg.sender).transfer(tempBalance);

        AfterValueTransfer(msg.sender);

        assert(_currentPlayersToGameIdMap[msg.sender] == 0);

        emit CashOutEvent(game.Id, msg.sender, tempBalance);
    }

    /**
     * @dev BeforeValueTransfer - hook function.
     * @param playerAddress Address of player to transfer value to.
     */
    function BeforeValueTransfer(address playerAddress) private {
        // Update before transfer to prevent re-entrancy.

        uint256 gameId = _idsToGameMap[_currentPlayersToGameIdMap[playerAddress]].Id;
        uint256 tempBalance = _idsToGameMap[_currentPlayersToGameIdMap[playerAddress]].SafeBalance;

        _currentPlayersToGameIdMap[playerAddress] = 0;
        delete _idsToGameMap[_currentPlayersToGameIdMap[playerAddress]];

        emit BeforeValueTransferEvent(gameId, playerAddress, tempBalance);
    }

    /**
     * @dev AfterValueTransfer - hook function.
     * @param playerAddress Address of player to transfer value to.
     */
    function AfterValueTransfer(address playerAddress) private {
        // Ensure transfer happened as expected. If not, update again.

        if(_currentPlayersToGameIdMap[playerAddress] != 0 || _idsToGameMap[_currentPlayersToGameIdMap[playerAddress]].SafeBalance != 0) {
            _currentPlayersToGameIdMap[playerAddress] = 0;
            delete _idsToGameMap[_currentPlayersToGameIdMap[playerAddress]];
        }

        emit AfterValueTransferEvent(playerAddress);
    }

    /**
     * @dev GetCard - Get a card from the deck. 11 is Joker, 12 is Queen, 13 is King, each worth 10 points.
     */
    function GetCard() private returns (uint256 cardValue) {
        cardValue = GenerateRandomNumber();
        
        // J, Q, K => 10
        if(cardValue > 10)
            cardValue = 10;
    }

    /**
     * @dev GenerateRandomNumber - Generates a random number between 1 and 13 based on the previous block's timestamp and difficulty.
     */
    function GenerateRandomNumber() private returns (uint256 randomNumber) {
        _rngCounter *= 21;
        uint256 seed = (block.timestamp + block.difficulty + _rngCounter) % 100;
        randomNumber = (uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), seed))) % 13 + 1);

        _rngCounter++;
            
        // reset RNG counter to prevent unecessary large number
        if(_rngCounter > 420000000)
            _rngCounter = randomNumber;

    }

    /**
     * @dev GetGame - helper function to get game info for msg.sender.
     */
    function GetGame() external view returns (Game memory game) {
        game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
    }
    
    /**
     * @dev ShowTable - helper function to display game info for msg.sender.
     */
    function ShowTable() external view returns (string memory DealerMessage, string memory PlayerCard1, 
                    string memory PlayerCard2, string memory PlayerNewCard, string memory PlayerCardTotal, string memory PlayerSplitTotal, 
                    string memory DealerCard1, string memory DealerCard2, string memory DealerNewCard, string memory DealerCardTotal, 
                    string memory PlayerBet, string memory Pot) {

        Game memory game = _idsToGameMap[_currentPlayersToGameIdMap[msg.sender]];
        
        DealerMessage = string.concat(" --> ", game.DealerMsg);
        PlayerCard1 = string.concat(" --> ", Strings.toString(game.PlayerCard1));
        PlayerCard2 = string.concat(" --> ", Strings.toString(game.PlayerCard2));
        PlayerNewCard = string.concat(" --> ", Strings.toString(game.PlayerNewCard));
        PlayerCardTotal = string.concat(" ------> ", Strings.toString(game.PlayerCardTotal));
        PlayerSplitTotal = string.concat(" ------> ", Strings.toString(game.PlayerSplitTotal));
        DealerCard1 = string.concat(" --> ", Strings.toString(game.DealerCard1));
        DealerCard2 = string.concat(" --> ", Strings.toString(game.DealerCard2));
        DealerNewCard = string.concat(" --> ", Strings.toString(game.DealerNewCard));
        DealerCardTotal = string.concat(" ------> ", Strings.toString(game.DealerCardTotal));
        PlayerBet = string.concat(" --> ", Strings.toString(game.PlayerBet), " wei");
        Pot = string.concat(" --> ", Strings.toString(game.SafeBalance), " wei");
    }
    
}