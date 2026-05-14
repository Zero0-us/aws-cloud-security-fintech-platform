'use client';
import { useState } from 'react';
import { useRouter, useParams } from 'next/navigation';
import { useQuery } from '@tanstack/react-query';
import { useRecoilValue } from 'recoil';
import clsx from 'clsx';
import Header from '@/components/Header';
import ProductListItem from '@/components/ProductListItem';
import { bankDataAtom } from '@/store/atoms';
import { getProductList } from '@/api/product';
import { IProduct, ProductType } from '@/models';

export default function ProductListPage() {
  const router = useRouter();
  const params = useParams();
  const bankData = useRecoilValue(bankDataAtom);
  const [type, setType] = useState<ProductType>(params.type as ProductType);
  const { data } = useQuery({
    queryKey: ['ProductList', bankData.bankId, type],
    queryFn: () => getProductList({ bankId: bankData.bankId, productType: type, isDone: false }),
  });

  const tabs: { label: string; value: ProductType }[] = [
    { label: '입출금통장', value: 'ORDINARY_DEPOSIT' },
    { label: '정기예금', value: 'TERM_DEPOSIT' },
    { label: '정기적금', value: 'FIXED_DEPOSIT' },
  ];

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="상품목록" goBack={() => router.push('/main')} menu={[{ title: 'close', onPress: () => router.back() }]} />
      <div className="w-full h-14 flex flex-row justify-around items-end bg-gray-100">
        {tabs.map((tab) => (
          <button key={tab.value} onClick={() => setType(tab.value)}
            className={clsx('flex-grow h-10 flex justify-center items-center cursor-pointer',
              type === tab.value ? 'border-x-2 border-t-2 border-pink-200 bg-gray-100' : 'border border-gray-300 bg-gray-200')}>
            <span className="text-xl font-medium text-gray-700">{tab.label}</span>
          </button>
        ))}
      </div>
      <div className="overflow-auto flex-grow bg-gray-200">
        {data && (
          <div className="w-full flex flex-col pb-4 px-1 gap-4 bg-gray-200">
            {data.page?.content?.map((product: IProduct) => (
              <ProductListItem key={product.productId} product={product}
                link={() => router.push(`/accounts/create?product=${encodeURIComponent(JSON.stringify(product))}`)} />
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
