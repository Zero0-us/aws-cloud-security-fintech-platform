'use client';
import { useRouter, useSearchParams } from 'next/navigation';
import { MdAccountCircle } from 'react-icons/md';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import { IAccount } from '@/models';

export default function CreateAccountResultPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const account: IAccount = JSON.parse(searchParams.get('account') || '{}');

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌 개설" menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="flex-grow flex flex-col mb-16">
        <div className="flex flex-col flex-grow justify-center items-center gap-2 pb-20">
          <div className="w-14 h-14 m-6 bg-pink-300 rounded-full flex justify-center items-center">
            <MdAccountCircle size={35} className="text-white" />
          </div>
          <div className="flex flex-row"><span className="text-2xl font-bold text-gray-700">{`내 ${account.nickname}`}</span><span className="text-2xl font-medium text-gray-700">을</span></div>
          <span className="text-2xl font-medium text-gray-700">성공적으로 개설했어요</span>
        </div>
        <div className="h-32 flex flex-col justify-evenly">
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">계좌 이름</span><span className="font-semibold text-sm text-gray-700">{account.nickname}</span></div>
          <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">계좌번호</span><span className="font-semibold text-sm text-gray-700">{`조아은행 ${account.accountId}`}</span></div>
        </div>
      </div>
      <BottomButton title="확인" onPress={() => router.push('/main')} />
    </div>
  );
}
