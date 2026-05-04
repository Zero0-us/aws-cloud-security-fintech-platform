'use client';
import { useEffect, useState } from 'react';
import { useRouter } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { useRecoilValue } from 'recoil';
import Header from '@/components/Header';
import Footer from '@/components/Footer';
import AccountCarousel from '@/components/AccountCarousel';
import AccountCarouselIndicator from '@/components/AccountCarouselIndicator';
import { getAccountList } from '@/api/account';
import { memberDataAtom, bankDataAtom } from '@/store/atoms';
import { IAccount, ProductType } from '@/models';

export default function MainPage() {
  const router = useRouter();
  const memberData = useRecoilValue(memberDataAtom);
  const bankData = useRecoilValue(bankDataAtom);
  const [page, setPage] = useState(0);
  const { data, refetch } = useQuery({ queryKey: ['accountList'], queryFn: getAccountList });

  useEffect(() => {
    if (!memberData.isLogin) router.replace('/');
  }, [memberData.isLogin, router]);

  const accountList: IAccount[] = data?.page?.content || [];
  const menuItems: { title: string; type: ProductType }[] = [
    { title: '입출금통장', type: 'ORDINARY_DEPOSIT' },
    { title: '정기예금', type: 'TERM_DEPOSIT' },
    { title: '정기적금', type: 'FIXED_DEPOSIT' },
  ];

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header menu={[
        { title: 'magnify', onPress: () => router.push('/search') },
        { title: 'menu', onPress: () => router.push('/menu') },
      ]} />
      <div className="w-full px-6 pt-8 pb-4">
        <span className="text-xl font-semibold text-gray-700">
          {memberData.member?.name}님의 계좌
        </span>
      </div>
      {accountList.length > 0 ? (
        <div className="relative bg-pink-50 rounded-3xl mx-4">
          <AccountCarousel
            accountList={accountList}
            router={router}
            setPage={setPage}
            refetch={refetch}
          />
          <AccountCarouselIndicator total={accountList.length} current={page} />
        </div>
      ) : (
        <div className="mx-4 p-8 bg-pink-50 rounded-3xl flex flex-col items-center gap-4">
          <span className="text-gray-500">계좌가 없습니다.</span>
          <button
            onClick={() => router.push('/products/ORDINARY_DEPOSIT')}
            className="px-4 py-2 bg-pink-200 rounded-full cursor-pointer"
          >
            <span className="font-semibold text-gray-700">계좌 개설하기</span>
          </button>
        </div>
      )}
      <div className="w-full px-4 py-8">
        <span className="text-lg font-semibold text-gray-700 px-2">금융상품</span>
        <div className="flex flex-col gap-2 mt-4">
          {menuItems.map((item) => (
            <button
              key={item.type}
              onClick={() => router.push(`/products/${item.type}`)}
              className="w-full h-14 bg-white rounded-xl flex items-center px-6 shadow-sm cursor-pointer"
            >
              <span className="text-base font-medium text-gray-700">{item.title}</span>
            </button>
          ))}
        </div>
      </div>
      <Footer />
    </div>
  );
}
