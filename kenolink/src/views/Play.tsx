import { VStack, Heading, FormControl, FormLabel, Button, Box, Select, Checkbox } from '@chakra-ui/react';
import React, { useState, useEffect } from 'react';
import { useMoralis, useWeb3ExecuteFunction } from "react-moralis";
import "../App.css";

export const Play = () => {
  const [level, setLevel] = useState<string>('1');
  const [numbers, setNumbers] = useState<string[]>(['0']);
  const [keno, setKeno] = useState<string>('0');
  const [entered, setEntered] = useState<any>([]);
  const [past, setPast] = useState<any>([]);
  const [paidout, setPaidout] = useState<any>([]);
  const [round, setRound] = useState('4'); // add as useEffect( getRound )
  const { account, isAuthenticated } = useMoralis();
  const { Moralis } = useMoralis();
  const contractProcessor = useWeb3ExecuteFunction();
  const fee = 10 * 10 ** 10;
  const address: string = "0x09DAB6083BA5fA644826a14EE45f1651AAB19509"

  const onChangeHandler = (event: React.ChangeEvent<HTMLSelectElement>) => {
    const { selectedOptions } = event.currentTarget;
    var newNumbers = ['0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0', '0'];
    for (let i = 0; i < selectedOptions.length; i++) {
      newNumbers[i] = (selectedOptions[i].value);
    }
    newNumbers = newNumbers.splice(-12);
    setNumbers(newNumbers);
  };


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
/*
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
  async function enter(level: string, numbers: string[], value: any) {
    let options = {
      contractAddress: address,
      functionName: "enter",
      abi: [
        {
          inputs: [
            {
              internalType: "uint256",
              name: "_level",
              type: "uint256"
            },
            {
              internalType: "uint256[12]",
              name: "_numbers",
              type: "uint256[12]"
            }
          ],
          name: "enter",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        },
      ],
      params: {
        _level: level,
        _numbers: numbers,
      },
      msgValue: value,
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

  async function withdraw(round: string) {
    let options = {
      contractAddress: address,
      functionName: "withdraw",
      abi: [{
          inputs: [
            {
              internalType: "int",
              name: "_round",
              type: "int"
            },
          ],
          name: "withdraw",
          outputs: [],
          stateMutability: "payable",
          type: "function",
        }],
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
    async function fetchEntered() {
      const Logs = Moralis.Object.extend("KenolinkLogs");
      const query = new Moralis.Query(Logs);
      query.equalTo("name", "playerEntered");
      query.equalTo("player", account);
      query.equalTo("round", round);
      //const withdrawn = new Moralis.Query(Logs); //possibly replace with isActive(round), else just roll with it
      //withdrawn.equalTo("name", "playerWithdrew");
      //withdrawn.equalTo("player", account);
      //query.doesNotMatchKeyInQuery("round", "round", withdrawn)
      const result = await query.find()
      setEntered(result);
    }
    fetchEntered();
  }, [account]);


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
      {(account && (entered.length < 1)) &&
      <Box width="full">
        <form
          onSubmit={(event) => {
            event.preventDefault();
            // solidity contract : enter()
          }}
        >
          <Heading mb={4}>Next round</Heading>
          <VStack>
            <FormControl>
              <FormLabel>Level</FormLabel>
              <Select required value={level} onChange={(event) => setLevel(event.target.value)}>
                <option value="1">1</option>
                <option value="2">2</option>
                <option value="3">3</option>
                <option value="4">4</option>
                <option value="5">5</option>
                <option value="6">6</option>
                <option value="7">7</option>
                <option value="8">8</option>
                <option value="9">9</option>
                <option value="10">10</option>
                <option value="11">11</option>
              </Select>
            </FormControl>
            <FormControl>
              <FormLabel>Numbers</FormLabel>
              <div className="container">
                <select multiple size={5} onChange={onChangeHandler} className="select">
                  <option value="1">1</option>
                  <option value="2">2</option>
                  <option value="3">3</option>
                  <option value="4">4</option>
                  <option value="5">5</option>
                  <option value="6">6</option>
                  <option value="7">7</option>
                  <option value="8">8</option>
                  <option value="9">9</option>
                  <option value="10">10</option>
                  <option value="11">11</option>
                  <option value="12">12</option>
                  <option value="13">13</option>
                  <option value="14">14</option>
                  <option value="15">15</option>
                  <option value="16">16</option>
                  <option value="17">17</option>
                  <option value="18">18</option>
                  <option value="19">19</option>
                  <option value="20">20</option>
                  <option value="21">21</option>
                  <option value="22">22</option>
                  <option value="23">23</option>
                  <option value="24">24</option>
                  <option value="25">25</option>
                  <option value="26">26</option>
                  <option value="27">27</option>
                  <option value="28">28</option>
                  <option value="29">29</option>
                  <option value="30">30</option>
                  <option value="31">31</option>
                  <option value="32">32</option>
                  <option value="33">33</option>
                  <option value="34">34</option>
                  <option value="35">35</option>
                  <option value="36">36</option>
                  <option value="37">37</option>
                  <option value="38">38</option>
                  <option value="39">39</option>
                  <option value="40">40</option>
                  <option value="41">41</option>
                  <option value="42">42</option>
                  <option value="43">43</option>
                  <option value="44">44</option>
                  <option value="45">45</option>
                  <option value="46">46</option>
                  <option value="47">47</option>
                  <option value="48">48</option>
                  <option value="49">49</option>
                  <option value="50">50</option>
                  <option value="51">51</option>
                  <option value="52">52</option>
                  <option value="53">53</option>
                  <option value="54">54</option>
                  <option value="55">55</option>
                  <option value="56">56</option>
                  <option value="57">57</option>
                  <option value="58">58</option>
                  <option value="59">59</option>
                  <option value="60">60</option>
                  <option value="61">61</option>
                  <option value="62">62</option>
                  <option value="63">63</option>
                  <option value="64">64</option>
                  <option value="65">65</option>
                  <option value="66">66</option>
                  <option value="67">67</option>
                  <option value="68">68</option>
                  <option value="69">69</option>
                  <option value="70">70</option>
                </select>
                <div>
                  {numbers &&
                    numbers.map((number) => <span className="number">{number}</span>)}
                </div>
              </div>
            </FormControl>
            <Button type="submit" width="full" colorScheme="blue" onClick={() => enter(level, numbers, fee)}>
              Enter
            </Button>
          </VStack>
        </form>
      </Box>
      }
      {(account && entered.length > 0) &&
      <Box width="full">
        <div>
          Your played row:
          {entered.map((e: any) => 
          <span className="number">{e.attributes.numbers}</span>)}
        </div>
        <Button type="submit" width="full" colorScheme="red" onClick={() => withdraw(round)}>
          Withdraw
        </Button>
      </Box>
      }
    </VStack>
  );
};
