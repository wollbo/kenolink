/* eslint-disable no-console */
import "../App.css";
import React from "react";
import Board from "../components/Board";
import { useMoralis } from 'react-moralis';


export const Nfts = () => {

  const squares = Array.from(Array(71).keys()).map((x) => x + 1);
  const { Moralis } = useMoralis();



  const getRound = async function () {

    const options = {
      chain: "0x13881",
      address: "0xD91212683F8F7e3010dAaa9E29031A518453ebd9",
      function_name: "getRound",
      abi:
      {
        inputs: [{ hej: "hilding" }],
        name: "getRound",
        outputs: [
          {
            internalType: "int256",
            name: "",
            type: "int256"
          }
        ],
        stateMutability: "view",
        type: "function"
      },
      params: {},
    } as const;

    const round = await Moralis.Web3API.native.runContractFunction(options);
    console.log(round);
    return round;
  }

  return (
    <div>
      <Board squares={squares} />
    </div>
  );
};
