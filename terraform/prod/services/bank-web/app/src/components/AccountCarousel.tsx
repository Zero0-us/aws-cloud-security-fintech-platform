'use client';
import { IAccount } from '@/models';
import AccountCarouselItem from './AccountCarouselItem';
import { useRef, useState } from 'react';
import { AppRouterInstance } from 'next/dist/shared/lib/app-router-context.shared-runtime';

interface IProps {
  accountList: IAccount[];
  router: AppRouterInstance;
  setPage: React.Dispatch<React.SetStateAction<number>>;
  refetch: () => void;
}

export default function AccountCarousel({ accountList, router, setPage, refetch }: IProps) {
  const scrollRef = useRef<HTMLDivElement>(null);

  const onScroll = () => {
    if (!scrollRef.current) return;
    const el = scrollRef.current;
    const pageWidth = el.clientWidth;
    const newPage = Math.round(el.scrollLeft / pageWidth);
    setPage(newPage);
  };

  return (
    <div
      ref={scrollRef}
      onScroll={onScroll}
      className="flex flex-row overflow-x-auto snap-x snap-mandatory scrollbar-hide"
      style={{ scrollbarWidth: 'none' }}
    >
      {accountList.map((account) => (
        <AccountCarouselItem
          key={account.accountId}
          account={account}
          router={router}
          refetch={refetch}
        />
      ))}
    </div>
  );
}
