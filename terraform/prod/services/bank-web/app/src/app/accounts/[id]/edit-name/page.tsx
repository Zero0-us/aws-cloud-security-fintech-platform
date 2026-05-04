'use client';
import { useRouter, useParams, useSearchParams } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import { updateAccount } from '@/api/account';

export default function ChangeAccountNamePage() {
  const router = useRouter();
  const params = useParams();
  const searchParams = useSearchParams();
  const accountId = params.id as string;
  const nickname = searchParams.get('nickname') || '';

  const mutation = useMutation({
    mutationFn: updateAccount,
    onSuccess: () => router.push('/main'),
    onError: (err) => console.log(err),
  });

  const { control, handleSubmit, formState: { errors } } = useForm({ defaultValues: { nickname } });

  const onSubmit = (data: { nickname: string }) => {
    mutation.mutate({ accountId, nickname: data.nickname, password: '1234' });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="계좌이름 변경" goBack={() => router.back()} menu={[{ title: 'close', onPress: () => router.back() }]} />
      <CommonInput label="계좌이름">
        <Controller control={control}
          rules={{ required: '계좌이름을 입력해주세요.', maxLength: { value: 20, message: '계좌이름을 최대 20자이내로 작성해주세요' }, validate: { correct: (v) => v === nickname ? '계좌 이름이 기존과 동일합니다.' : true } }}
          render={({ field: { onChange, onBlur, value } }) => (
            <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} />
          )} name="nickname" />
        <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.nickname?.message}</span>
      </CommonInput>
      <BottomButton title="변경" onPress={handleSubmit(onSubmit)} />
    </div>
  );
}
