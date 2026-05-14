'use client';
import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { MdArrowBack } from 'react-icons/md';
import Header from '@/components/Header';
import { IAccount } from '@/models';
import { formatAmount } from '@/utils';
import { getAccountDetail } from '@/api/account';

export default function TransferAmountPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const accountId = searchParams.get('accountId') || '';
  const toAccountId = searchParams.get('toAccountId') || '';
  const toAccountName = searchParams.get('toAccountName') || '';
  const [account, setAccount] = useState<IAccount | null>(null);
  const [amount, setAmount] = useState('');

  useEffect(() => { getAccountDetail({ accountId }).then((res) => setAccount(res.data)); }, [accountId]);

  if (!account) return null;

  const changeAmount = (char: string) => () => {
    setAmount((prev) => {
      const newVal = prev + char;
      return +newVal > account.balance ? String(account.balance) : newVal;
    });
  };

  const keys = [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['00', '0', 'del']];

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="이체" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="flex flex-col flex-grow justify-center gap-8 pb-2 px-8">
        <div className="flex flex-col gap-2">
          <div className="flex flex-row"><span className="text-xl font-bold text-gray-700">{account.nickname}</span><span className="text-xl font-medium text-gray-700">에서</span></div>
          <span className="text-sm font-medium text-gray-700">{`잔액 ${formatAmount(account.balance)}원`}</span>
        </div>
        <div className="flex flex-col gap-2">
          <div className="flex flex-row"><span className="text-xl font-bold text-gray-700">{toAccountName}</span><span className="text-xl font-medium text-gray-700">으로</span></div>
          <span className="text-sm font-medium text-gray-700">{toAccountId}</span>
        </div>
        <div className="flex flex-col gap-2">
          <span className="w-full text-xl font-bold text-gray-700">{amount === '' ? '금액 입력' : `${formatAmount(+amount)}원`}</span>
          <button onClick={() => setAmount(account.balance.toString())} className="self-start py-1 px-2 rounded-full bg-pink-100 text-sm font-medium text-gray-700 cursor-pointer">
            {`잔액 ${formatAmount(account.balance)}원 입력`}
          </button>
        </div>
      </div>
      {amount !== '' && (
        <button onClick={() => router.push(`/transfer/confirm?accountId=${accountId}&toAccountId=${toAccountId}&toAccountName=${toAccountName}&amount=${amount}`)}
          className="w-full h-16 bg-pink-200 flex justify-center items-center shadow-sm cursor-pointer">
          <span className="text-2xl font-semibold text-gray-700">확인</span>
        </button>
      )}
      <div className="px-8 py-1">
        {keys.map((row, ri) => (
          <div key={ri} className="flex flex-row justify-around">
            {row.map((k) => (
              <button key={k} onClick={k === 'del' ? () => setAmount((p) => p.slice(0, -1)) : changeAmount(k)}
                className="w-20 h-16 flex justify-center items-center cursor-pointer">
                {k === 'del' ? <MdArrowBack size={36} className="text-gray-400" /> : <span className="text-4xl font-bold text-gray-400">{k}</span>}
              </button>
            ))}
          </div>
        ))}
      </div>
    </div>
  );
}
