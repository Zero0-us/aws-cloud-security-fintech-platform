'use client';
import { useRouter, useParams } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { MdEdit } from 'react-icons/md';
import Header from '@/components/Header';
import CommonMenuItem from '@/components/CommonMenuItem';
import { getAccountDetail } from '@/api/account';
import { formatAmount } from '@/utils';

export default function AccountDetailPage() {
  const router = useRouter();
  const params = useParams();
  const accountId = params.id as string;
  const { data } = useQuery({ queryKey: ['accountDetail', accountId], queryFn: () => getAccountDetail({ accountId }) });
  const account = data?.data;
  if (!account) return null;

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌관리" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="w-full h-56 p-6">
        <div className="flex flex-col gap-2">
          <span className="text-sm font-medium text-gray-400">{account.accountId}</span>
          <div className="flex flex-row items-center gap-4">
            <span className="text-2xl font-bold text-gray-700">{account.nickname}</span>
            <button onClick={() => router.push(`/accounts/${accountId}/edit-name`)} className="cursor-pointer">
              <MdEdit size={20} className="text-gray-500" />
            </button>
          </div>
          <div className="w-full flex flex-row pt-4">
            <div className="w-1/2 flex flex-col gap-1">
              <span className="text-sm font-semibold text-gray-700">상품명</span>
              <span className="text-sm font-semibold text-gray-700">개설일</span>
              <span className="text-sm font-semibold text-gray-700">출금가능금액</span>
              <span className="text-sm font-semibold text-gray-700">적용금리</span>
            </div>
            <div className="w-1/2 flex flex-col gap-1">
              <span className="text-sm font-semibold text-gray-500">입출금통장</span>
              <span className="text-sm font-semibold text-gray-500">{account.startDate}</span>
              <span className="text-sm font-semibold text-gray-500">{`${formatAmount(account.balance)}원`}</span>
              <span className="text-sm font-semibold text-gray-500">연 0.10%</span>
            </div>
          </div>
        </div>
      </div>
      <div className="overflow-auto flex-grow">
        <CommonMenuItem title="계좌 비밀번호 재설정" underline />
        <CommonMenuItem title="계좌 거래한도 변경" underline onPress={() => router.push(`/accounts/${accountId}/edit-limit`)} />
        <CommonMenuItem title="비밀번호 오류횟수 초기화" underline />
        <CommonMenuItem title="거래내역 다운로드" underline />
        <div className="w-full flex justify-center py-4 px-8">
          <span className="text-sm text-gray-400">
            계좌를 해지하시려면{' '}
            <button onClick={() => router.push(`/accounts/${accountId}/delete`)} className="underline text-gray-700 cursor-pointer">여기</button>
            를 눌러주세요.
          </span>
        </div>
      </div>
    </div>
  );
}
