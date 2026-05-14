'use client';
import { useRouter, useParams, useSearchParams } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import { changeLimit } from '@/api/account';

export default function ChangeAccountLimitPage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const accountId = params.id as string;
  const transferLimit = searchParams.get('limit') || '0';

  const mutation = useMutation({
    mutationFn: changeLimit,
    onSuccess: () => router.push('/main'),
    onError: (err) => console.log(err),
  });

  const { control, handleSubmit, formState: { errors } } = useForm({ defaultValues: { transferLimit } });

  const onSubmit = (data: { transferLimit: string }) => {
    mutation.mutate({ accountId, transferLimit: +data.transferLimit });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌한도 변경" menu={[{ title: 'close', onPress: () => router.back() }]} />
      <CommonInput label="계좌 한도 (만원)">
        <Controller control={control} rules={{ required: '계좌한도을 입력해주세요.' }}
          render={({ field: { onChange, onBlur, value } }) => (
            <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} inputMode="numeric" />
          )} name="transferLimit" />
        <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.transferLimit?.message}</span>
      </CommonInput>
      <BottomButton title="변경" onPress={handleSubmit(onSubmit)} />
    </div>
  );
}
