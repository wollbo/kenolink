import React from 'react';
import { Container, Spacer, HStack, Text, Flex } from '@chakra-ui/react';
import { Authenticate } from '../components/Authenticate';
import { Connect } from '../components/Connect';
import { MoralisLogo } from '../assets/MoralisLogo';
import logo from "../assets/kenolink.png";
import { Navigation } from './Navigation';

const Header = () => {
  return (
    <Container maxW="container.lg" py={4}>
      <HStack>
        <img className="logo" src={logo} alt="" width="20%"></img>
        <Navigation />
        <Spacer />
        <Connect />
      </HStack>
    </Container>
  );
};

export default Header;
