'use client';
import { useRouter } from 'next/navigation';
import { MdLock, MdVisibility, MdVisibilityOff } from 'react-icons/md';
import { useState } from 'react';
import Header from '@/components/Header';
import CommonInput from '@/components/CommonInput';
import BottomButton from '@/components/BottomButton';

export default function ChangePasswordPage() {
  const router = useRouter();
  const [showPw, setShowPw] = useState(false);
  const [showPw2, setShowPw2] = useState(false);

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="새로운 비밀번호 입력" menu={[{ title: 'close', onPress: () => router.back() }]} />
      <div className="flex-grow mb-16">
        <div className="flex flex-col flex-grow justify-center items-center gap-2 py-16">
          <div className="w-14 h-14 m-6 bg-pink-300 rounded-full flex justify-center items-center">
            <MdLock size={35} className="text-white" />
          </div>
          <div className="flex flex-row"><span className="text-2xl font-bold">내 입출금통장</span><span className="text-2xl font-medium">의</span></div>
          <span className="text-2xl font-medium">새로운 비밀번호를 입력해주세요</span>
        </div>
        <div className="h-80 flex flex-col justify-evenly">
          <CommonInput label="비밀번호">
            <div className="w-full relative">
              <input className="w-full border-b border-gray-800/50 outline-none bg-transparent" type={showPw ? 'text' : 'password'} />
              <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPw(!showPw)}>
                {showPw ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}
              </button>
            </div>
          </CommonInput>
          <CommonInput label="비밀번호 확인">
            <div className="w-full relative">
              <input className="w-full border-b border-gray-800/50 outline-none bg-transparent" type={showPw2 ? 'text' : 'password'} />
              <button className="absolute right-0 top-0 translate-y-3 p-2 cursor-pointer" onClick={() => setShowPw2(!showPw2)}>
                {showPw2 ? <MdVisibility size={20} className="text-gray-500" /> : <MdVisibilityOff size={20} className="text-gray-500" />}
              </button>
            </div>
          </CommonInput>
        </div>
      </div>
      <BottomButton title="비밀번호 변경" />
    </div>
  );
}
