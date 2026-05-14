'use client';
import { useRouter, useParams } from 'next/navigation';
import { useEffect, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { MdDeleteOutline } from 'react-icons/md';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import { deleteAccount, getAccountDetail } from '@/api/account';
import { IAccount } from '@/models';
import { formatAmount } from '@/utils';

export default function DeleteAccountPage() {
  const router = useRouter();
  const params = useParams();
  const accountId = params.id as string;
  const [account, setAccount] = useState<IAccount | null>(null);

  useEffect(() => {
    getAccountDetail({ accountId }).then((res) => setAccount(res.data));
  }, [accountId]);

  const mutation = useMutation({
    mutationFn: deleteAccount,
    onSuccess: () => router.push('/main'),
    onError: (err) => console.log(err),
  });

  if (!account) return null;

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌 해지" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="flex-grow flex flex-col mb-16">
        <div className="flex flex-col flex-grow justify-center items-center gap-2">
          <div className="w-14 h-14 m-6 bg-pink-300 rounded-full flex justify-center items-center">
            <MdDeleteOutline size={40} className="text-white" />
          </div>
          <div className="flex flex-row">
            <span className="text-2xl font-bold text-gray-700">{`내 ${account.nickname}`}</span>
            <span className="text-2xl font-medium text-gray-700">을</span>
          </div>
          <span className="text-2xl font-medium text-gray-700">정말로 해지하시겠어요?</span>
        </div>
        <div className="h-48 flex flex-col justify-evenly">
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">계좌 번호</span><span className="font-semibold text-sm text-gray-700">{account.accountId}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">계좌 잔액</span><span className="font-semibold text-sm text-gray-700">{`${formatAmount(account.balance)}원`}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">개설일</span><span className="font-semibold text-sm text-gray-700">{account.startDate}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">만기일</span><span className="font-semibold text-sm text-gray-700">{account.endDate}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">휴면계좌 여부</span><span className="font-semibold text-sm text-gray-700">{account.isDormant ? 'Y' : 'N'}</span></div>
        </div>
      </div>
      <BottomButton title="확인" onPress={() => mutation.mutate({ accountId: account.accountId, password: '1234' })} />
    </div>
  );
}
