'use client';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import Header from '@/components/Header';
import AccountListItem from '@/components/AccountListItem';
import { getAccountList } from '@/api/account';
import { IAccount } from '@/models';

export default function AccountListPage() {
  const router = useRouter();
  const { data } = useQuery({ queryKey: ['accountList'], queryFn: getAccountList });

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="내 계좌 목록" goBack={() => router.push('/main')} menu={[{ title: 'close', onPress: () => router.back() }]} />
      <div className="w-full overflow-auto">
        {data && (
          <div className="w-full flex flex-col py-12 px-6 gap-4">
            <div className="w-full h-10 bg-pink-200 rounded-xl flex items-center px-6 shadow-sm">
              <span className="text-base font-semibold text-gray-700">{`계좌 ${data?.page?.totalElements}개`}</span>
            </div>
            {data.page?.content?.map((account: IAccount) => (
              <AccountListItem key={account.accountId} account={account} link={() => router.push(`/accounts/${account.accountId}/history`)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
