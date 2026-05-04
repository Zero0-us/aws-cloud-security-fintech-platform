'use client';
import { useRouter } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useRecoilState } from 'recoil';
import Header from '@/components/Header';
import BottomButton from '@/components/BottomButton';
import { memberDataAtom } from '@/store/atoms';

export default function EditProfilePage() {
  const router = useRouter();
  const [memberData, setMemberData] = useRecoilState(memberDataAtom);
  const { control, handleSubmit, formState: { errors } } = useForm({ defaultValues: { name: memberData.member!.name } });

  const onSubmit = (data: { name: string }) => {
    setMemberData((prev) => prev);
  };

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="사용자 정보 변경" menu={[{ title: 'close', onPress: () => router.back() }]} />
      <div className="w-full h-24 p-8 flex justify-center items-center">
        <span className="text-xl font-bold text-gray-700">{memberData.member?.email}</span>
      </div>
      <div className="h-48 flex flex-col justify-evenly">
        <div className="flex flex-row justify-between px-6">
          <span className="font-bold text-sm text-gray-700">이름</span>
          <div className="flex w-1/2 relative">
            <Controller control={control} rules={{ required: '이름을 입력해주세요.', maxLength: { value: 8, message: '이름은 최대 8자입니다.' } }}
              render={({ field: { onChange, onBlur, value } }) => (
                <input className="w-full border-b border-gray-800/50 font-bold text-sm text-gray-700 py-0 text-right px-1 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} />
              )} name="name" />
            <span className="absolute -bottom-4 right-1 text-red-400 text-xs">{errors.name?.message}</span>
          </div>
        </div>
        <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">전화번호</span><span className="font-semibold text-sm text-gray-700">{memberData.member?.phone}</span></div>
        <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">가입일</span><span className="font-semibold text-sm text-gray-700">{memberData.member?.createdAt}</span></div>
        <div className="flex flex-row justify-between px-6"><span className="font-bold text-sm text-gray-700">최근 수정일</span><span className="font-semibold text-sm text-gray-700">{memberData.member?.updatedAt}</span></div>
      </div>
      <BottomButton title="변경" onPress={handleSubmit(onSubmit)} />
    </div>
  );
}
