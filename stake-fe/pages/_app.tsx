import '../styles/globals.css';
import '@rainbow-me/rainbowkit/styles.css';
import type { AppProps } from 'next/app';

import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { WagmiProvider } from 'wagmi';
import {
  sepolia,
} from 'wagmi/chains';
import {defineChain} from 'viem';
import { getDefaultConfig, RainbowKitProvider } from '@rainbow-me/rainbowkit';

const localTest = defineChain({
  id: 31_337,
  name: 'LocalTest',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'lETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] },
  },
})

const config = getDefaultConfig({
  appName: 'DUGGEE 质押平台',
  projectId: 'YOUR_PROJECT_ID',
  chains: [
    localTest,
    ...(process.env.NEXT_PUBLIC_ENABLE_TESTNETS === 'true' ? [sepolia] : []),
  ],
  ssr: true,
});

const client = new QueryClient();

function MyApp({ Component, pageProps }: AppProps) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={client}>
        <RainbowKitProvider>
          <Component {...pageProps} />
        </RainbowKitProvider>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default MyApp;
