# Kenolink

A digital keno lottery powered by Chainlink VRF and Chainlink Automation

## Overview

Keno is a lottery form where players get to decide whether they want to have a larger chance of winning or the chance to win big. Now, powered by smart contracts and Chainlink services, Keno is available to play on the Polygon Mumbai testnet.

## Try it out
The kenolink lottery is available to play at http://kenolink.xyz/
Players select between 1 and 11 numbers in the range [1, 70]. The payout tables are the same as the ones provided by Svenska Spel at https://www.svenskaspel.se/keno/resultat except that 10 SEK = 100 GWEI. If enough players have entered, 20 random numbers will be drawn by a Chainlink keeper at 22:30 UTC from a VRF subscription. 
Kenolink also support the bonus game mode King Keno. From the 20 drawn numbers, an additional "King" is chosen, and players participating in this game mode will get an extra payout if the King is one of their played numbers. To enter King Keno, players have to add a non-zero twelth number to their row.



