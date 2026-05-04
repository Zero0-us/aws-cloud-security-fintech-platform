'use client';
import { useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { MdCardGiftcard, MdSavings } from 'react-icons/md';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import BottomPopup from '@/components/BottomPopup';
import { formatAmount, getProductTypeName } from '@/utils';
import { ProductPaymentTypeName, IProduct } from '@/models';

export default function CreateAccountPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const product: IProduct = JSON.parse(searchParams.get('product') || '{}');
  const [detailOpen, setDetailOpen] = useState(false);

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌 개설" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="overflow-auto flex-grow mb-16">
        <div className="w-full bg-purple-400 flex flex-col gap-8 items-center p-8 justify-between">
          <div className="w-full flex flex-col gap-3">
            <span className="text-lg font-medium text-gray-50">{getProductTypeName(product.productType)!.title}</span>
            <span className="text-4xl text-gray-50">{product.name}</span>
          </div>
          <div className="w-full px-4 flex flex-row items-center justify-around">
            <div className="flex flex-col items-center gap-1">
              <MdCardGiftcard size={50} className="text-gray-200" />
              <span className="text-xs text-gray-50">이자율</span>
              <span className="text-lg text-gray-50 font-bold">{`연 ${product.rate}%`}</span>
            </div>
            <div className="flex flex-col items-center gap-1">
              <MdSavings size={50} className="text-gray-200" />
              <span className="text-xs text-gray-50">지급방식</span>
              <span className="text-lg text-gray-50 font-bold">{ProductPaymentTypeName[product.paymentType]}</span>
            </div>
          </div>
          <button onClick={() => setDetailOpen(true)} className="w-80 h-14 bg-purple-900/70 flex justify-center items-center cursor-pointer">
            <span className="text-xl text-gray-50 font-medium">자세히보기</span>
          </button>
        </div>
        <div className="w-full flex flex-col p-6">
          <span className="text-2xl mb-4 font-semibold text-gray-700">{getProductTypeName(product.productType)!.description}</span>
          <span className="text-base font-medium text-gray-700">{product.description}</span>
        </div>
      </div>
      <BottomButton title="신청하기" onPress={() => router.push(`/accounts/create/confirm?product=${encodeURIComponent(JSON.stringify(product))}`)} />
      {detailOpen && (
        <BottomPopup close={() => setDetailOpen(false)}>
          <div className="w-full p-6 flex flex-col gap-2">
            {[
              ['상품분류', getProductTypeName(product.productType)!.title],
              ['상품명', product.name],
              ['종료여부', product.isDone ? 'Y' : 'N'],
              ['저축 최소한도', `${formatAmount(product.minAmount)}원`],
              ['저축 최대한도', `${formatAmount(product.maxAmount)}원`],
              ['이자율', `연 ${product.rate}%`],
              ['지급방식', ProductPaymentTypeName[product.paymentType]],
            ].map(([k, v]) => (
              <div key={k} className="w-full flex flex-row justify-between">
                <span className="text-base font-semibold text-gray-700">{k}</span>
                <span className="text-gray-700">{v}</span>
              </div>
            ))}
          </div>
          <BottomButton title="확인" onPress={() => setDetailOpen(false)} />
        </BottomPopup>
      )}
    </div>
  );
}
