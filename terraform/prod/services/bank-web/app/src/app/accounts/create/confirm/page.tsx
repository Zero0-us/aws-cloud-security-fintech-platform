'use client';
import { useState, useEffect } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useMutation, useQuery } from '@tanstack/react-query';
import { useRecoilValue } from 'recoil';
import { MdVisibility, MdVisibilityOff } from 'react-icons/md';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import LoadingScreen from '@/components/LoadingScreen';
import DropdownInput from '@/components/DropdownInput';
import OptionInput from '@/components/OptionInput';
import { bankDataAtom } from '@/store/atoms';
import { createAccount, getAccountList } from '@/api/account';
import { IProduct } from '@/models';
import { calculateRate, formatAmount } from '@/utils';

interface CreateAccountForm { withdrawAccount: string; amount: string; password: string; password2: string; term: number; taxType: 'TAX' | 'NO_TAX'; }

export default function CreateAccountConfirmPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const product: IProduct = JSON.parse(searchParams.get('product') || '{}');
  const bankData = useRecoilValue(bankDataAtom);
  const { data } = useQuery({ queryKey: ['accountList'], queryFn: getAccountList });
  const mutation = useMutation({
    mutationFn: createAccount,
    onSuccess: (res) => router.push(`/accounts/create/result?account=${encodeURIComponent(JSON.stringify(res.data))}`),
    onError: (err) => console.log(err),
  });

  const { control, handleSubmit, getValues, setValue, watch, formState: { errors } } = useForm<CreateAccountForm>({
    defaultValues: { withdrawAccount: '', amount: '0', term: 6, password: '', password2: '', taxType: 'TAX' },
  });

  const [calcValue, setCalcValue] = useState({ totalPrincipal: 0, calculatedInterest: 0, taxInterest: 0, totalAmount: 0 });
  const [showPw, setShowPw] = useState(false);
  const [showPw2, setShowPw2] = useState(false);

  useEffect(() => {
    const sub = watch(() => setCalcValue(calculateRate(product, +getValues('amount'), getValues('term'), getValues('taxType'))));
    return () => sub.unsubscribe();
  }, [watch, getValues, product]);

  const onSubmit = (fd: CreateAccountForm) => {
    mutation.mutate({ amount: Number(fd.amount), taxType: fd.taxType, term: fd.term, withdrawAccount: fd.withdrawAccount || null, nickname: product.name, password: fd.password, bankId: bankData.bankId, productId: product.productId });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌 생성 신청" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.push('/main') }]} />
      <div className="overflow-auto flex-grow flex flex-col mb-16">
        <div className="flex h-52 justify-center items-center flex-col gap-2">
          <div className="flex flex-row"><span className="text-2xl font-bold text-gray-700">{`내 ${product.name}`}</span><span className="text-2xl font-medium text-gray-700">의</span></div>
          <span className="text-2xl font-medium text-gray-700">필수 정보를 입력해주세요</span>
        </div>
        <div className="flex flex-col justify-evenly">
          {product.productType !== 'ORDINARY_DEPOSIT' && (
            <>
              <CommonInput label="출금 계좌">
                <Controller control={control} rules={{ required: '출금 계좌를 선택해주세요.' }}
                  render={() => <DropdownInput data={data?.page?.content || []} labelField="nickname" valueField="accountId" search placeholder="출금 계좌를 선택해주세요." value={watch('withdrawAccount')} setValue={(v) => setValue('withdrawAccount', v)} />} name="withdrawAccount" />
                <span className="absolute bottom-4 left-8 text-red-400 text-sm">{errors.withdrawAccount?.message}</span>
              </CommonInput>
              <CommonInput label="시작 금액 (원)">
                <Controller control={control} rules={{ required: '시작 금액을 입력해주세요.' }}
                  render={({ field: { onChange, onBlur, value } }) => (
                    <div className="w-full relative">
                      <div className="py-3 flex flex-row gap-3 flex-wrap">
                        {[{ l: '만원', v: '10000' }, { l: '5만원', v: '50000' }, { l: '100만원', v: '1000000' }, { l: '500만원', v: '5000000' }, { l: '1,000만원', v: '10000000' }].map(b => (
                          <button key={b.v} onClick={() => setValue('amount', b.v)} className="text-sm font-medium py-1 px-2 rounded-full bg-pink-100 text-gray-700 cursor-pointer">{b.l}</button>
                        ))}
                      </div>
                      <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} inputMode="numeric" placeholder="직접 입력" />
                    </div>
                  )} name="amount" />
                <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.amount?.message}</span>
              </CommonInput>
              <OptionInput label="기간" options={[{ label: '6개월', value: 6 }, { label: '1년', value: 12 }, { label: '2년', value: 24 }, { label: '3년', value: 36 }]} value={watch('term')} setValue={(v) => setValue('term', v)} />
              <OptionInput label="과세 유형" options={[{ label: '과세', value: 'TAX' }, { label: '비과세', value: 'NO_TAX' }]} value={watch('taxType')} setValue={(v) => setValue('taxType', v)} />
              <CommonInput label="만기시 지급액">
                <div className="w-full flex flex-col gap-1 border p-4 rounded-sm border-gray-300 bg-gray-200 mt-4">
                  {[['원금합계', calcValue.totalPrincipal], ['세전이자', calcValue.calculatedInterest]].map(([k, v]) => (
                    <div key={k as string} className="w-full flex flex-row justify-between"><span className="text-base font-semibold text-gray-400">{k}</span><span className="text-base font-medium text-gray-400">{`${formatAmount(v as number)}원`}</span></div>
                  ))}
                  <div className="w-full flex flex-row justify-between"><span className="text-base font-semibold text-red-400">{`이자과세(${watch('taxType') === 'TAX' ? '15.4' : '0'}%)`}</span><span className="text-base font-medium text-red-400">{`${formatAmount(calcValue.taxInterest)}원`}</span></div>
                  <div className="w-full flex flex-row justify-between"><span className="text-base font-semibold text-gray-400">세후수령액</span><span className="text-base font-medium text-gray-400">{`${formatAmount(calcValue.totalAmount)}원`}</span></div>
                </div>
              </CommonInput>
            </>
          )}
          <CommonInput label="계좌 비밀번호">
            <Controller control={control} rules={{ required: '계좌 비밀번호를 입력해주세요.' }}
              render={({ field: { onChange, onBlur, value } }) => (
                <div className="w-full relative">
                  <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} type={showPw ? 'text' : 'password'} maxLength={4} inputMode="numeric" />
                  <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPw(!showPw)}>{showPw ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}</button>
                </div>
              )} name="password" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.password?.message}</span>
          </CommonInput>
          <CommonInput label="계좌 비밀번호 확인">
            <Controller control={control} rules={{ required: '계좌 비밀번호를 한번 더 입력해주세요.', validate: { correct: (v) => v === getValues('password') ? true : '비밀번호가 일치하지 않습니다.' } }}
              render={({ field: { onChange, onBlur, value } }) => (
                <div className="w-full relative">
                  <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} type={showPw2 ? 'text' : 'password'} maxLength={4} inputMode="numeric" />
                  <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPw2(!showPw2)}>{showPw2 ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}</button>
                </div>
              )} name="password2" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.password2?.message}</span>
          </CommonInput>
        </div>
      </div>
      <BottomButton title="신청하기" onPress={handleSubmit(onSubmit)} />
      <LoadingScreen isLoading={mutation.isPending} />
    </div>
  );
}
