'use client';
import { useState, useEffect } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useMutation, useQuery } from '@tanstack/react-query';
import { MdSearch, MdSettings, MdRefresh, MdExpandMore } from 'react-icons/md';
import Header from '@/components/Header';
import HistoryItem from '@/components/HistoryItem';
import BottomPopup from '@/components/BottomPopup';
import BottomButton from '@/components/BottomButton';
import OptionInput from '@/components/OptionInput';
import { getAccountDetail } from '@/api/account';
import { getTransactionList } from '@/api/transaction';
import { IAccount, ITransaction } from '@/models';
import { formatAmount, formatDate } from '@/utils';

const typeName = [
  { value: 'ALL', label: '전체' },
  { value: 'DEPOSIT_ONLY', label: '입금만' },
  { value: 'WITHDRAWAL_ONLY', label: '출금만' },
];

export default function HistoryPage() {
  const router = useRouter();
  const params = useParams();
  const accountId = params.id as string;
  const [filterOpen, setFilterOpen] = useState(false);
  const [fromDate, setFromDate] = useState(formatDate(new Date(new Date().setMonth(new Date().getMonth() - 1))));
  const [term, setTerm] = useState(1);
  const [type, setType] = useState(0);
  const [latest, setLatest] = useState(true);
  const [keyword, setKeyword] = useState('');
  const [account, setAccount] = useState<IAccount | null>(null);

  const accountMutation = useMutation({
    mutationFn: getAccountDetail,
    onSuccess: (data) => setAccount(data.data),
  });

  useEffect(() => { accountMutation.mutate({ accountId }); }, [accountId]);

  const { data } = useQuery({
    queryKey: ['transactionList', accountId, fromDate, typeName[type].value, latest ? 'LATEST' : 'OLDEST'],
    queryFn: () => getTransactionList({
      fromDate, accountId, toDate: formatDate(new Date()),
      searchType: typeName[type].value === 'ALL' ? null : typeName[type].value,
      orderBy: latest ? 'LATEST' : 'OLDEST',
    }),
    enabled: !!account,
  });

  if (!account) return null;

  const renderList = (list: ITransaction[], word: string) => {
    let balance = account.balance;
    return list.filter((t) => t.depositorName.includes(word)).map((t) => {
      const oldBalance = balance;
      if (t.fromAccount === accountId) balance += t.amount;
      else if (t.toAccount === accountId) balance -= t.amount;
      return (
        <HistoryItem key={t.transactionId} date={t.createdAt.slice(2, 10)} title={t.depositorName}
          amount={t.fromAccount === accountId ? -t.amount : +t.amount} balance={type === 0 && latest ? oldBalance : undefined} />
      );
    });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header stack="계좌 거래내역" goBack={() => router.back()} menu={[{ title: 'menu', onPress: () => router.push('/menu') }]} />
      <div className="bg-pink-100 w-full h-48">
        <div className="w-full flex flex-row justify-between p-6">
          <div className="flex flex-col gap-2">
            <span className="font-semibold text-lg text-gray-700">{account.nickname}</span>
            <span className="font-medium text-base underline text-gray-500">{account.accountId}</span>
          </div>
          <div className="flex flex-row gap-2">
            <button onClick={() => accountMutation.mutate({ accountId })} className="cursor-pointer"><MdRefresh size={20} className="text-gray-500" /></button>
            <button onClick={() => router.push(`/accounts/${accountId}`)} className="cursor-pointer"><MdSettings size={20} className="text-gray-500" /></button>
          </div>
        </div>
        <div className="w-full flex flex-row justify-center items-center gap-2">
          <span className="text-2xl font-bold text-gray-700">{formatAmount(account.balance)}</span>
          <span className="text-sm font-semibold text-gray-700">원</span>
        </div>
      </div>
      <div className="w-full overflow-auto">
        <div className="flex flex-row items-center justify-between w-full h-12 px-2 border-b border-gray-300">
          <MdSearch size={25} className="text-gray-500" />
          <input className="flex-grow text-gray-700 outline-none bg-transparent px-2" onChange={(e) => setKeyword(e.target.value)} value={keyword} />
          <button onClick={() => setFilterOpen(true)} className="flex flex-row items-center cursor-pointer">
            <span className="text-sm font-light text-gray-700">{`${term}개월·${typeName[type].label}·${latest ? '최신순' : '과거순'}`}</span>
            <MdExpandMore size={25} className="text-gray-500" />
          </button>
        </div>
        {data?.page?.content?.length > 0 && (
          <div className="w-full flex flex-col gap-2 pb-4">
            {renderList(data.page.content, keyword)}
          </div>
        )}
      </div>
      {filterOpen && (
        <BottomPopup close={() => setFilterOpen(false)}>
          <div className="w-full flex flex-col flex-grow gap-8">
            <OptionInput label="조회기간" options={[{ label: '1개월', value: 1 }, { label: '3개월', value: 3 }, { label: '6개월', value: 6 }]}
              value={term} setValue={(v) => { setTerm(v); setFromDate(formatDate(new Date(new Date().setMonth(new Date().getMonth() - v)))); }} />
            <OptionInput label="거래유형" options={[{ label: '전체', value: 0 }, { label: '입금만', value: 1 }, { label: '출금만', value: 2 }]}
              value={type} setValue={setType} />
            <OptionInput label="거래내역정렬" options={[{ label: '최신순', value: true }, { label: '과거순', value: false }]}
              value={latest} setValue={setLatest} />
          </div>
          <BottomButton title="확인" onPress={() => setFilterOpen(false)} />
        </BottomPopup>
      )}
    </div>
  );
}
