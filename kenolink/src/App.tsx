import React from 'react';
import { Routes, Route } from 'react-router-dom';
import Home from './views/Home';
import Header from './layout/Header';
import Main from './layout/Main';
import Footer from './layout/Footer';
import { VStack, Spacer } from '@chakra-ui/react';
import { Play } from './views/Play';
import { Past } from './views/Past';


function App() {
  return (
    <VStack minHeight="100vh">
      <Header />
      <Main>
        <Routes>
          <Route index element={<Home />} />
          <Route path="play" element={<Play />} />
          <Route path="past" element={<Past />} />
        </Routes>
      </Main>
      <Spacer />
      <Footer />
    </VStack>
  );
}

export default App;
