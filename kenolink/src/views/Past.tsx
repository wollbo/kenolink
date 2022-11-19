import { VStack, Heading, FormControl, FormLabel, Button, Box, Select, Checkbox } from '@chakra-ui/react';
import React, { useState, useEffect } from 'react';
import { useMoralis, useWeb3ExecuteFunction } from "react-moralis";
import "../App.css";

export const Past = () => {
  const [level, setLevel] = useState<string>('1');
  const [numbers, setNumbers] = useState<string[]>(['0']);
  const [keno, setKeno] = useState<string>('0');
  const [entered, setEntered] = useState<any>([]);
  const [past, setPast] = useState<any>([]);
  const [paidout, setPaidout] = useState<any>([]);
  const [round, setRound] = useState(4); // add as useEffect( getRound )
  const { account, isAuthenticated } = useMoralis();
  const { Moralis } = useMoralis();
  const contractProcessor = useWeb3ExecuteFunction();
  const fee = 10 * 10 ** 10;
  const address: string = "0x09DAB6083BA5fA644826a14EE45f1651AAB19509"

/*
  const getRound = async function () {
    const options = {
      chain: "0x13881",
      address: address,
      function_name: "getRound",
      abi: [{
        inputs: [],
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
      }],
      params: {}
    } as const;
    console.log(options);
    const round = await Moralis.Web3API.native.runContractFunction(options);
    console.log(round);
    return round;
  }

  const getReserve = async function () {
    const options = {
      chain: "0x13881" as const,
      address: "0xD91212683F8F7e3010dAaa9E29031A518453ebd9" as const,
      function_name: "getReserve" as const,
      abi:
      {
        inputs: [],
        name: "getReserve",
        outputs:
        {
          internalType: "uint256",
          name: "",
          type: "uint256",
        },
        stateMutability: "view",
        type: "function",
      },
      params: {},
    };
    const reserve = await Moralis.Web3API.native.runContractFunction(options);
    console.log(reserve);
    return reserve;
  };
*/

  async function payout(round: string) {
    let options = {
      contractAddress: address,
      functionName: "payout",
      abi: [
        {
          inputs: [
            {
              internalType: "int256",
              name: "_round",
              type: "int256"
            },
          ],
          name: "payout",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      params: {
        _round: round,
      },
    };
    await contractProcessor.fetch({
      params: options,
      onSuccess: () => {
      console.log('succesful!')
      },
      onError: (error) => {
        console.log(error);
      },
    });
  }

  useEffect(() => {
    async function fetchPast() {
      const Logs = Moralis.Object.extend("KenolinkLogs");
      const query = new Moralis.Query(Logs);
      query.equalTo("name", "playerEntered");
      query.equalTo("player", account);
      query.notEqualTo("round", round); // string, so easier to just do not equal than lesser

      const withdrawn = new Moralis.Query(Logs); //possibly replace with isActive(round), else just roll with it
      withdrawn.equalTo("name", "playerWithdrew");
      withdrawn.equalTo("player", account);
      query.doesNotMatchKeyInQuery("round", "round", withdrawn)

      const paidout = new Moralis.Query(Logs);
      paidout.equalTo("name", "playerPayout");
      paidout.equalTo("player", account);
      query.doesNotMatchKeyInQuery("round", "round", paidout)
      const result = await query.find()
      //console.log(result);
      setPast(result);
    }
    fetchPast();
  }, [account]);

  useEffect(() => {
    async function fetchPaidout() {
      const Logs = Moralis.Object.extend("KenolinkLogs");
      const paidout = new Moralis.Query(Logs);
      paidout.equalTo("name", "playerPayout");
      paidout.equalTo("player", account);
      const result = await paidout.find()
      //console.log(result);
      setPaidout(result);
    }
    fetchPaidout();
  }, [account]);

  useEffect(() => {
    async function fetchRound() {
      const Logs = Moralis.Object.extend("KenolinkLogs");
      const rounds = new Moralis.Query(Logs);
      rounds.equalTo("name", "newWinner");
      rounds.descending("round");
      const result = await rounds.find()
      setRound(result[0].attributes.round+1);
      console.log(round);
    }
    fetchRound();
  }, [account]);

  return (
    <VStack alignItems={'start'}>
      {!account &&
      <div>
        Authenticate to enter the game!
      </div>
      }
      {(account && past.length > 0) &&
      <Box width="full">
        <div>
          Your past games:
          {past.map((e: any) =>
            <div>
              <span className="number">{e.attributes.numbers}</span>
              Round: {e.attributes.round}
              <Button type="submit" width="full" colorScheme="red" onClick={() => payout(e.attributes.round)}>
                Payout
              </Button>
            </div>
            )
          }
        </div>
      </Box>
      }
    </VStack>
  );
};
