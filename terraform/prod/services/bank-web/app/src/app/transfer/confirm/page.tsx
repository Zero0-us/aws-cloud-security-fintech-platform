'use client';
import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { useRecoilValue } from 'recoil';
import { useMutation } from '@tanstack/react-query';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import { memberDataAtom } from '@/store/atoms';
import { getAccountDetail } from '@/api/account';
import { transferSend } from '@/api/transaction';
import { IAccount } from '@/models';
import { formatAmount } from '@/utils';

export default function TransferConfirmPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const accountId = searchParams.get('accountId') || '';
  const toAccountId = searchParams.get('toAccountId') || '';
  const toAccountName = searchParams.get('toAccountName') || '';
  const amount = Number(searchParams.get('amount') || '0');
  const memberData = useRecoilValue(memberDataAtom);
  const [account, setAccount] = useState<IAccount | null>(null);

  useEffect(() => { getAccountDetail({ accountId }).then((res) => setAccount(res.data)); }, [accountId]);

  const mutation = useMutation({
    mutationFn: transferSend,
    onSuccess: () => router.push(`/transfer/result?amount=${amount}&depositorName=${memberData.member!.name}&accountNickname=${account!.nickname}&toAccountId=${toAccountId}&toAccountName=${toAccountName}`),
    onError: (err) => console.log(err),
  });

  if (!account) return null;

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="이체" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="flex-grow mb-16">
        <div className="flex flex-col flex-grow justify-center items-center gap-2 py-20">
          <div className="flex flex-row"><span className="text-2xl font-bold text-gray-700">{toAccountName}</span><span className="text-2xl font-medium text-gray-700">으로</span></div>
          <span className="text-2xl font-medium text-gray-700">{`${formatAmount(amount)}원을`}</span>
          <span className="text-2xl font-medium text-gray-700">보낼까요?</span>
        </div>
        <div className="h-48 flex flex-col justify-evenly">
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">받는 분에게 표시</span><span className="font-semibold text-sm text-gray-700">{memberData.member?.name}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">출금 계좌</span><span className="font-semibold text-sm text-gray-700">{`내 ${account.nickname}`}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">입금 계좌</span><span className="font-semibold text-sm text-gray-700">{toAccountId}</span></div>
        </div>
      </div>
      <BottomButton title="이체" onPress={() => mutation.mutate({ password: '1234', amount, depositorName: memberData.member?.name, fromAccount: accountId, toAccount: toAccountId })} />
    </div>
  );
}
