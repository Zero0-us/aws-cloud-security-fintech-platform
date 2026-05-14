'use client';
import { IAccount } from '@/models';
import { formatAmount } from '@/utils';
import { MdRefresh } from 'react-icons/md';
import { AppRouterInstance } from 'next/dist/shared/lib/app-router-context.shared-runtime';

interface IProps {
  account: IAccount;
  router: AppRouterInstance;
  refetch: () => void;
}

export default function AccountCarouselItem({ account, router, refetch }: IProps) {
  return (
    <div className="min-w-full snap-start py-4 px-6 flex flex-col gap-2">
      <div className="w-full">
        <button
          onClick={() => router.push(`/accounts/${account.accountId}/history`)}
          className="cursor-pointer"
        >
          <span className="text-md text-gray-700">{account?.nickname}</span>
        </button>
        <p className="text-md text-gray-700">{account?.accountId}</p>
      </div>
      <div className="w-full flex flex-row items-center justify-center gap-2">
        <span className="text-2xl font-bold text-gray-700">
          {`${formatAmount(account?.balance)}원`}
        </span>
        <button onClick={refetch} className="cursor-pointer">
          <MdRefresh size={20} className="text-gray-400" />
        </button>
      </div>
      <div className="w-full flex flex-row items-center justify-center gap-2">
        <button
          onClick={() => router.push(`/transfer?accountId=${account.accountId}`)}
          className="flex items-center justify-center w-12 h-6 bg-pink-300 rounded-full cursor-pointer"
        >
          <span className="text-sm font-semibold text-gray-700">이체</span>
        </button>
      </div>
    </div>
  );
}
