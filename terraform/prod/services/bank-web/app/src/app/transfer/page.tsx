'use client';
import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useMutation, useQuery } from '@tanstack/react-query';
import { MdExpandMore, MdExpandLess } from 'react-icons/md';
import Header from '@/components/Header';
import AccountSelectItem from '@/components/AccountSelectItem';
import BottomButton from '@/components/BottomButton';
import { getAccountDetail, getAccountList } from '@/api/account';
import { IAccount } from '@/models';
import { formatAmount } from '@/utils';

export default function TransferPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const accountId = searchParams.get('accountId') || '';
  const [account, setAccount] = useState<IAccount | null>(null);
  const [toAccountId, setToAccountId] = useState('');
  const [myAccountOpen, setMyAccountOpen] = useState(false);
  const { data } = useQuery({ queryKey: ['accountList'], queryFn: getAccountList });

  useEffect(() => {
    if (accountId) getAccountDetail({ accountId }).then((res) => setAccount(res.data));
  }, [accountId]);

  const mutation = useMutation({
    mutationFn: getAccountDetail,
    onSuccess: (res) => router.push(`/transfer/amount?accountId=${accountId}&toAccountId=${toAccountId}&toAccountName=${res.data.nickname}`),
    onError: () => window.alert('계좌를 찾을 수 없습니다.'),
  });

  if (!account) return null;

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header stack="이체" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="w-full h-36 border-t border-b border-gray-300 my-6 flex flex-col justify-evenly py-2 px-6">
        <span className="font-semibold text-base text-gray-700">{account.nickname}</span>
        <span className="text-2xl underline text-gray-400">{account.accountId}</span>
        <div className="w-full flex items-end"><span className="text-gray-700">{`출금가능금액: ${formatAmount(account.balance)}원`}</span></div>
      </div>
      <div className="h-24 w-full p-6">
        <div className="w-full border-b border-gray-400 flex flex-row items-center pr-2">
          <input placeholder="계좌번호 입력" className="flex-grow text-xl px-4 text-gray-700 outline-none bg-transparent placeholder:text-gray-700" onChange={(e) => setToAccountId(e.target.value)} value={toAccountId} inputMode="numeric" />
        </div>
      </div>
      <div className="w-full overflow-auto mb-16">
        <div className="w-full flex flex-col">
          <button onClick={() => setMyAccountOpen((p) => !p)} className="w-full flex flex-row justify-between items-center px-6 py-4 cursor-pointer">
            <span className="font-bold text-base px-2 text-gray-700">내 계좌</span>
            {myAccountOpen ? <MdExpandLess size={30} className="text-gray-500" /> : <MdExpandMore size={30} className="text-gray-500" />}
          </button>
          {myAccountOpen && data?.page?.content?.filter((i: IAccount) => i.accountId !== accountId).map((item: IAccount) => (
            <AccountSelectItem key={item.accountId} account={item} onPress={() => setToAccountId(item.accountId)} />
          ))}
        </div>
      </div>
      <BottomButton title="확인" onPress={() => mutation.mutate({ accountId: toAccountId })} />
    </div>
  );
}
