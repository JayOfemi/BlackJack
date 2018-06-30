# BlackJack.sol
A Solidity smart contract game of Blackjack that can be deployed on the blockchain.


This contract can be tested on any Solidity IDE, but the one I used to create this contract was Remix (https://remix.ethereum.org). Remix Documentation: https://remix.readthedocs.io/en/latest/

Copy the BlackJack.sol code into the IDE.

Increase Gas Limit to 5000000 or higher.

Deploy the contract.

Type a number between 1 and 1000000 wei in the "Value" field and click the "payContract" button.

Once contract is paid, your address is registered as the player

NOTE: PLAYER MUST CLICK ON THE "DISPLAYTABLE" BUTTON AFTER EVERY MOVE TO REFRESH THE DISPLAY

Player can then place a bet to begin the game (1 wei < bet < 1000 wei).


RULES:

This contract follows the regular rules of BlackJack: https://www.bicyclecards.com/how-to-play/blackjack/

  -Player hits/stands to beat dealer's hand by getting as close to 21 as possible.
  
  -Reno Rule: Player can only double down on 9, 10, or 11.
  
  -Split Under 21 Rule

Split Under 21 Rule:
Modified split - If either of the player's hand in a split beats dealer, 
player wins bet on both hands automatically.
But if Player busts on either deck, Dealer wins bet on both decks.

On a split hand, If player's first hand has a standoff with dealer, 
player's other hand must beat dealer, otherwise dealer wins.
If player's second hand stands off with dealer, player gets original bet back.

On a split hand, the Player's split total is updated first, then when player stands, 
the Player's card total is updated. If either of these totals beats the dealer, 
player wins the split and receives the bet on both cards.


Player can either double down or split, player cannot split
then double down and vice versa.

If a button is clicked and the contract does not respond, check the Terminal (output) section of the window, where the contract will provide a reason.

DISCLOSURE: This contract uses a psuedo-random number generator that can be influenced by miners. Be careful when using this or a contract like this in a Casino Dapp for example, where real money is used. This contract protects against security issues like Re-Entrancy, and makes certain that only the player can use any of the functions in the game's interface. The contract has not been tested thoroughly enough to guarantee protection against other kinds of attacks. This repository is open to the public. Feel free to Fork and pull requests to help improve the code.
