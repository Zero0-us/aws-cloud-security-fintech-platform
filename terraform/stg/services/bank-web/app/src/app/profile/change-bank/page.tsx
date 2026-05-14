'use client';
import { useRouter } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import { useSetRecoilState } from 'recoil';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import { bankDataAtom, memberDataAtom } from '@/store/atoms';
import { axiosInstance } from '@/api';
import { getBankDetail } from '@/api/bank';
import { logout } from '@/api/member';

export default function ChangeBankIdPage() {
  const router = useRouter();
  const setBankData = useSetRecoilState(bankDataAtom);
  const setMemberData = useSetRecoilState(memberDataAtom);

  const { control, handleSubmit, getValues, setError, formState: { errors } } = useForm({ defaultValues: { bankId: '', apiKey: '' } });

  const logoutMutation = useMutation({
    mutationFn: logout,
    onSuccess: () => {
      axiosInstance.interceptors.request.clear();
      axiosInstance.interceptors.request.use((config) => { config.headers.memberId = ''; config.headers.apiKey = getValues('apiKey'); return config; }, (error) => Promise.reject(error));
      setMemberData({ isLogin: false, member: null });
      router.replace('/');
    },
  });

  const bankMutation = useMutation({
    mutationFn: getBankDetail,
    onSuccess: (res) => {
      setBankData({ bankId: res.data.bankId, bankName: res.data.name, apiKey: getValues('apiKey') });
      logoutMutation.mutate();
    },
    onError: () => {
      setError('bankId', { type: 'notValid', message: '유효하지 않은 은행코드입니다.' });
      setError('apiKey', { type: 'notValid', message: '유효하지 않은 apiKey입니다.' });
    },
  });

  const onSubmit = (data: { bankId: string; apiKey: string }) => bankMutation.mutate({ bankId: data.bankId, apiKey: data.apiKey });

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="은행코드 변경" menu={[{ title: 'close', onPress: () => router.back() }]} />
      <CommonInput label="은행코드">
        <Controller control={control} rules={{ required: '은행코드를 입력해주세요.' }}
          render={({ field: { onChange, onBlur, value } }) => <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} />} name="bankId" />
        <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.bankId?.message}</span>
      </CommonInput>
      <CommonInput label="API Key">
        <Controller control={control} rules={{ required: 'API Key를 입력해주세요.' }}
          render={({ field: { onChange, onBlur, value } }) => <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} />} name="apiKey" />
        <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.apiKey?.message}</span>
      </CommonInput>
      <BottomButton title="변경" onPress={handleSubmit(onSubmit)} />
    </div>
  );
}
