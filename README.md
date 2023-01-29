# BlackJack.sol

A Solidity smart contract game of Blackjack that can be deployed on the blockchain.

PLEASE READ BELOW BEFORE PLAYING THE GAME OR USING THIS CONTRACT.

This contract can be tested on any Solidity IDE, but the one I used to create this contract was Remix: https://remix.ethereum.org. Remix Documentation: https://remix-ide.readthedocs.io/en/latest/

In the "Compiler" tab, make sure the Compiler Version matches the contract (0.8.12 or greater), then click "Compile".

NOTE: If not deployed on a testnet or mainnet, a local blockchain is needed to generate the random numbers used in this contract. Consider using Hardhat to deploy a local blockchain for testing: https://docs.openzeppelin.com/learn/deploying-and-interacting.

In the "Deploy" tab, ensure "Environment" is set to Hardhat Provider, or any other testing environment you are using, if available.

Deploy the contract.

Enter a deposit amount greater than 1000 GWei and up to 10 Ether in the "Value" field and click the "StartNewGame" button in the contract (1000 GWei < deposit <= 10 Ether).

Once a game is started, the invoking address is registered as the player.

Player can then place a bet to begin a game round (100 GWei <= bet <= 1 Ether).

NOTE: Player must click "ShowTable" after each move to refresh the table info display.


RULES:

This contract follows the regular rules of BlackJack: https://www.bicyclecards.com/how-to-play/blackjack/

  * Player hits/stands to beat dealer's hand by getting as close to 21 as possible.

  * Dealer must hit on and up to 16 and stand on 17.
  
  * Player can only double down on 9, 10, or 11.

  * Player can either double down or split, player cannot split then double down and vice versa.

  * Player cannot split then split again or double down more than once.

  * Player who splits Aces can receive only one more additional card on a hand.

  * Player can get insurance if dealer might have a BlackJack.

  * Aces are high unless card total is already greater than 11.

  * Blackjack payout is 3:2.

  * No surrender.

If a button is clicked to call a contract function and the contract does not respond, check the Terminal/Output section (bottom pane) of the window, where the contract will provide a reason or an error.

DISCLOSURE: This contract uses a psuedo-random number generator that can be influenced by miners. Be careful when using this or a contract like this in a Casino Dapp for example, where real money is used. This contract protects against security issues like Re-Entrancy and forced payments through self destruct of another contract, and makes certain that only a player can use any of the functions in the game's interface. The contract has not been tested thoroughly enough to guarantee protection against all kinds of attacks. This repository is open to the public.
