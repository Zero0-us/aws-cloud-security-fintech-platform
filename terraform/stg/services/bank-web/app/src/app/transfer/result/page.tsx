'use client';
import { useRouter, useSearchParams } from 'next/navigation';
import { useRecoilValue } from 'recoil';
import { MdCheck } from 'react-icons/md';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import { bankDataAtom } from '@/store/atoms';
import { formatAmount } from '@/utils';

export default function TransferResultPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const amount = Number(searchParams.get('amount') || '0');
  const depositorName = searchParams.get('depositorName') || '';
  const accountNickname = searchParams.get('accountNickname') || '';
  const toAccountId = searchParams.get('toAccountId') || '';
  const toAccountName = searchParams.get('toAccountName') || '';
  const bankData = useRecoilValue(bankDataAtom);

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="이체" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="flex-grow mb-16">
        <div className="flex flex-col flex-grow justify-center items-center gap-2 py-16">
          <div className="w-14 h-14 m-6 bg-pink-300 rounded-full flex justify-center items-center">
            <MdCheck size={40} className="text-white" />
          </div>
          <div className="flex flex-row"><span className="text-2xl font-bold text-gray-700">{toAccountName}</span><span className="text-2xl font-medium text-gray-700">으로</span></div>
          <span className="text-2xl font-medium text-gray-700">{`${formatAmount(amount)}원을`}</span>
          <span className="text-2xl font-medium text-gray-700">보냈어요</span>
        </div>
        <div className="h-48 flex flex-col justify-evenly">
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">받는 분에게 표시</span><span className="font-semibold text-sm text-gray-700">{depositorName}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">출금 계좌</span><span className="font-semibold text-sm text-gray-700">{accountNickname}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">입금 계좌</span><span className="font-semibold text-sm text-gray-700">{`${bankData.bankName} ${toAccountId}`}</span></div>
        </div>
      </div>
      <BottomButton title="확인" onPress={() => router.push('/main')} />
    </div>
  );
}
