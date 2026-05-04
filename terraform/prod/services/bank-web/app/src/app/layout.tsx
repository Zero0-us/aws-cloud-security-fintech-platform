'use client';
import './globals.css';
import { RecoilRoot } from 'recoil';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useState } from 'react';
import Interceptor from '@/components/Interceptor';

export default function RootLayout({ children }: { children: React.ReactNode }) {
  const [queryClient] = useState(() => new QueryClient());

  return (
    <html lang="ko">
      <head>
        <title>조아은행 - JOA Bank</title>
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body>
        <RecoilRoot>
          <QueryClientProvider client={queryClient}>
            <Interceptor>
              {children}
            </Interceptor>
          </QueryClientProvider>
        </RecoilRoot>
      </body>
    </html>
  );
}
