'use client';
import { useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { Controller, useForm } from 'react-hook-form';
import { useMutation } from '@tanstack/react-query';
import { useRecoilValue } from 'recoil';
import { MdVisibility, MdVisibilityOff } from 'react-icons/md';
import clsx from 'clsx';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';
import LoadingScreen from '@/components/LoadingScreen';
import { bankDataAtom } from '@/store/atoms';
import { checkEmailCode, emailConfirm, emailSend, join } from '@/api/member';

interface JoinForm { email: string; name: string; phone: string; password: string; password2: string; }

export default function JoinPage() {
  const router = useRouter();
  const bankData = useRecoilValue(bankDataAtom);
  const [emailValid, setEmailValid] = useState(false);
  const [sendingEmail, setSendingEmail] = useState(false);
  const [emailCodeValid, setEmailCodeValid] = useState(false);
  const [emailCodeError, setEmailCodeError] = useState(false);
  const [emailCode, setEmailCode] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [showPassword2, setShowPassword2] = useState(false);
  const emailCount = useRef(300);
  const intervalId = useRef<any>(null);

  const joinMutation = useMutation({
    mutationFn: join,
    onSuccess: () => { window.alert('회원가입에 성공했습니다.'); router.replace('/'); },
    onError: (err) => console.log(err),
  });

  const emailMutation = useMutation({
    mutationFn: (params: string) => emailConfirm(params, bankData.bankId),
    onSuccess: () => { clearErrors('email'); setEmailValid(true); sendEmailCodeFn(); },
    onError: () => setError('email', { type: 'conflict', message: '중복된 이메일입니다.' }),
  });

  const { control, handleSubmit, getValues, setError, clearErrors, formState: { errors } } = useForm<JoinForm>({
    defaultValues: { email: '', name: '', phone: '', password: '', password2: '' },
  });

  const checkEmailValidFn = () => {
    const v = getValues('email');
    if (!v) { setError('email', { type: 'required', message: '이메일을 입력해주세요.' }); return; }
    if (!/^[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*@[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*\.[a-zA-Z]{2,3}$/.test(v)) {
      setError('email', { type: 'pattern', message: '올바른 이메일 형식이 아닙니다.' }); return;
    }
    emailMutation.mutate(v);
  };

  const sendEmailCodeFn = () => {
    emailSend({ email: getValues('email') }).then(() => {
      setSendingEmail(true);
      intervalId.current = setInterval(() => {
        emailCount.current -= 1;
        setError('email', { type: 'count', message: `${String(Math.floor(emailCount.current / 60)).padStart(2, '0')}:${String(emailCount.current % 60).padStart(2, '0')}` });
        if (emailCount.current < 0) {
          clearInterval(intervalId.current);
          setEmailValid(false); setSendingEmail(false); clearErrors('email');
          emailCount.current = 300;
        }
      }, 1000);
    });
  };

  const checkEmailCodeValidFn = () => {
    setEmailCodeError(false);
    checkEmailCode({ email: getValues('email'), code: emailCode })
      .then(() => { clearErrors('email'); setEmailCodeValid(true); setSendingEmail(false); clearInterval(intervalId.current); })
      .catch(() => setEmailCodeError(true));
  };

  const onSubmit = (data: JoinForm) => {
    if (!emailCodeValid) { setEmailCodeError(true); return; }
    joinMutation.mutate({ name: data.name, email: data.email, phone: data.phone.replaceAll('-', ''), password: data.password, bankId: bankData.bankId });
  };

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header stack="회원가입" goBack={() => router.push('/')} menu={[
        { title: 'home-outline', onPress: () => router.push('/') },
        { title: 'menu', onPress: () => router.push('/menu') },
      ]} />
      <div className="w-full overflow-auto pb-20">
        <div className="w-full flex flex-col pt-12 pb-16">
          <CommonInput label="이메일">
            <div className="w-full flex flex-col gap-4">
              <Controller control={control} rules={{ required: '이메일을 입력해주세요.', pattern: { value: /^[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*@[0-9a-zA-Z]([-_.]?[0-9a-zA-Z])*\.[a-zA-Z]{2,3}$/, message: '올바른 이메일 형식이 아닙니다.' }, validate: { code: () => emailCodeValid ? true : '이메일 인증을 해주세요.' } }}
                render={({ field: { onChange, onBlur, value } }) => (
                  <div className="w-full relative">
                    <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} type="email" disabled={emailValid} />
                    {!emailValid && !sendingEmail && (
                      <button onClick={checkEmailValidFn} className="absolute top-0 right-0 translate-y-1 border border-gray-400 rounded-full px-2 py-1 text-sm font-medium text-gray-700 cursor-pointer">인증번호 전송</button>
                    )}
                  </div>
                )} name="email" />
              <span className={clsx('absolute text-red-400 text-sm', sendingEmail ? 'bottom-10 left-2' : '-bottom-6 left-2')}>{errors.email?.message}</span>
              {emailValid && !sendingEmail && !emailCodeValid && <span className="absolute text-blue-400 -bottom-6 left-2 text-sm">인증번호를 전송중입니다.</span>}
              {emailCodeValid && <span className="absolute text-blue-400 -bottom-6 left-2 text-sm">이메일 인증이 완료되었습니다.</span>}
              {sendingEmail && (
                <div className="w-full relative">
                  <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onChange={(e) => setEmailCode(e.target.value)} />
                  <button onClick={checkEmailCodeValidFn} className="absolute top-0 right-0 translate-y-1 border border-gray-400 rounded-full px-2 py-1 text-sm font-medium text-gray-700 cursor-pointer">인증번호 확인</button>
                  {emailCodeError && <span className="absolute -bottom-6 left-2 text-red-400 text-sm">인증번호가 올바르지 않습니다.</span>}
                </div>
              )}
            </div>
          </CommonInput>
          <CommonInput label="이름">
            <Controller control={control} rules={{ required: '이름을 입력해주세요.', maxLength: { value: 8, message: '이름을 최대 8자이내로 작성해주세요' } }}
              render={({ field: { onChange, onBlur, value } }) => <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} />} name="name" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.name?.message}</span>
          </CommonInput>
          <CommonInput label="전화번호">
            <Controller control={control} rules={{ required: '전화번호을 입력해주세요.', pattern: { value: /^(01[016789]{1}|02|0[3-9]{1}[0-9]{1})-?[0-9]{3,4}-?[0-9]{4}$/, message: '올바른 전화번호 형식이 아닙니다.' } }}
              render={({ field: { onChange, onBlur, value } }) => <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value.replace(/[^0-9]/g, ''))} value={value} maxLength={11} inputMode="numeric" />} name="phone" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.phone?.message}</span>
          </CommonInput>
          <CommonInput label="비밀번호">
            <Controller control={control} rules={{ required: '비밀번호를 입력해주세요.' }}
              render={({ field: { onChange, onBlur, value } }) => (
                <div className="w-full relative">
                  <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} type={showPassword ? 'text' : 'password'} />
                  <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPassword(!showPassword)}>
                    {showPassword ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}
                  </button>
                </div>
              )} name="password" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.password?.message}</span>
          </CommonInput>
          <CommonInput label="비밀번호 확인">
            <Controller control={control} rules={{ required: '비밀번호를 한번 더 입력해주세요.', validate: { correct: (v) => v === getValues('password') ? true : '비밀번호가 일치하지 않습니다.' } }}
              render={({ field: { onChange, onBlur, value } }) => (
                <div className="w-full relative">
                  <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" onBlur={onBlur} onChange={(e) => onChange(e.target.value)} value={value} type={showPassword2 ? 'text' : 'password'} />
                  <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPassword2(!showPassword2)}>
                    {showPassword2 ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}
                  </button>
                </div>
              )} name="password2" />
            <span className="absolute bottom-2 left-8 text-red-400 text-sm">{errors.password2?.message}</span>
          </CommonInput>
        </div>
      </div>
      <BottomButton title="회원가입" onPress={handleSubmit(onSubmit)} />
      <LoadingScreen isLoading={joinMutation.isPending} />
    </div>
  );
}
