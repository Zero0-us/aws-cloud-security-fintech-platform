'use client';
import { useState, useEffect } from 'react';
import { useRouter } from 'next/navigation';
import { useRecoilValue, useSetRecoilState } from 'recoil';
import { Controller, useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import { MdPerson, MdLogin, MdVisibility, MdVisibilityOff } from 'react-icons/md';
import Header from '@/components/Header';
import BottomPopup from '@/components/BottomPopup';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import LoadingScreen from '@/components/LoadingScreen';
import { bankDataAtom, memberDataAtom } from '@/store/atoms';
import { login } from '@/api/member';
import { axiosInstance } from '@/api';
import { IMember } from '@/models';

interface LoginForm {
  email: string;
  password: string;
}

export default function IntroPage() {
  const router = useRouter();
  const setMemberData = useSetRecoilState(memberDataAtom);
  const bankData = useRecoilValue(bankDataAtom);
  const memberData = useRecoilValue(memberDataAtom);
  const [loginModalOpen, setLoginModalOpen] = useState(false);
  const [showPassword, setShowPassword] = useState(false);

  useEffect(() => {
    if (memberData.isLogin) router.replace('/main');
  }, [memberData.isLogin, router]);

  const mutation = useMutation({
    mutationFn: login,
    onSuccess: (data) => {
      const member: IMember = data.data;
      window.alert(`환영합니다. ${member.name}님`);
      axiosInstance.interceptors.request.clear();
      axiosInstance.interceptors.request.use(
        (config) => {
          config.headers.memberId = member.id;
          config.headers.apiKey = bankData.apiKey;
          return config;
        },
        (error) => Promise.reject(error)
      );
      setMemberData({ isLogin: true, member: data.data });
    },
    onError: (err) => console.log(err),
  });

  const { control, handleSubmit, formState: { errors }, reset } = useForm<LoginForm>({
    defaultValues: { email: '', password: '' },
  });

  useEffect(() => { reset(); }, [loginModalOpen, reset]);

  const onSubmit = (data: LoginForm) => {
    mutation.mutate({ email: data.email, password: data.password, bankId: bankData.bankId });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header menu={[
        { title: 'magnify', onPress: () => router.push('/search') },
        { title: 'menu', onPress: () => router.push('/menu') },
      ]} />
      <div className="w-full flex-grow bg-gray-100 pt-36 px-6 pb-24 flex flex-col justify-between min-h-[calc(100vh-4rem)]">
        <div className="w-full flex flex-col px-4 gap-2">
          <span className="font-semibold text-xl text-gray-700">{bankData.bankName}에</span>
          <span className="font-semibold text-xl text-gray-700">오신 것을 환영합니다.</span>
        </div>
        <div className="w-full flex flex-col gap-4 relative">
          <button
            onClick={() => router.push('/join')}
            className="w-full h-24 bg-pink-200 shadow-sm flex flex-row gap-8 items-center px-8 cursor-pointer"
          >
            <MdPerson size={30} className="text-gray-500" />
            <div className="flex flex-col gap-2">
              <span className="font-bold text-lg text-gray-700">회원가입</span>
              <span className="font-semibold text-xs text-gray-700">{bankData.bankName}이 처음이신가요?</span>
            </div>
          </button>
          <button
            onClick={() => setLoginModalOpen(true)}
            className="w-full h-24 bg-gray-200 shadow-sm flex flex-row gap-8 items-center px-8 cursor-pointer"
          >
            <MdLogin size={30} className="text-gray-500" />
            <div className="flex flex-col gap-2">
              <span className="font-bold text-lg text-gray-700">로그인</span>
              <span className="font-semibold text-xs text-gray-700">이미 {bankData.bankName}을 사용하고 계신가요?</span>
            </div>
          </button>
        </div>
      </div>
      {loginModalOpen && (
        <BottomPopup close={() => setLoginModalOpen(false)}>
          <div className="w-full flex flex-col flex-grow overflow-auto">
            <div className="w-full flex flex-col gap-6 mb-17 py-2">
              <CommonInput label="이메일">
                <Controller
                  control={control}
                  rules={{
                    required: '이메일을 입력해주세요.',
                    pattern: { value: /^[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*@[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*\.[a-zA-Z]{2,3}$/, message: '올바른 이메일 형식이 아닙니다.' },
                  }}
                  render={({ field: { onChange, onBlur, value } }) => (
                    <input
                      className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent"
                      onBlur={onBlur}
                      onChange={(e) => onChange(e.target.value)}
                      value={value}
                      type="email"
                      autoCapitalize="none"
                      autoCorrect="off"
                    />
                  )}
                  name="email"
                />
                <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.email?.message}</span>
              </CommonInput>
              <CommonInput label="비밀번호">
                <Controller
                  control={control}
                  rules={{ required: '비밀번호를 입력해주세요.' }}
                  render={({ field: { onChange, onBlur, value } }) => (
                    <div className="w-full relative">
                      <input
                        className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent"
                        onBlur={onBlur}
                        onChange={(e) => onChange(e.target.value)}
                        value={value}
                        type={showPassword ? 'text' : 'password'}
                      />
                      <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPassword(!showPassword)}>
                        {showPassword ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}
                      </button>
                    </div>
                  )}
                  name="password"
                />
                <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.password?.message}</span>
              </CommonInput>
              <div className="w-full flex flex-row justify-center gap-8">
                <button onClick={() => router.push('/join')} className="text-gray-700 cursor-pointer">회원가입</button>
                <span className="text-gray-700">|</span>
                <button className="text-gray-700 cursor-pointer">비밀번호 찾기</button>
              </div>
            </div>
          </div>
          <BottomButton title="로그인" onPress={handleSubmit(onSubmit)} />
        </BottomPopup>
      )}
      <LoadingScreen isLoading={false} />
    </div>
  );
}
