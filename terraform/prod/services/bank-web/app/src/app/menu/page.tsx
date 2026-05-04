'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { useRecoilState, useRecoilValue } from 'recoil';
import { useMutation } from '@tanstack/react-query';
import { MdSearch } from 'react-icons/md';
import clsx from 'clsx';
import Header from '@/components/Header';
import { memberDataAtom, bankDataAtom } from '@/store/atoms';
import { logout } from '@/api/member';
import { axiosInstance } from '@/api';

type MenuType = '뱅킹' | '이체' | '조회';

export default function MenuPage() {
  const router = useRouter();
  const [memberData, setMemberData] = useRecoilState(memberDataAtom);
  const bankData = useRecoilValue(bankDataAtom);
  const [keyword, setKeyword] = useState('');
  const [menu, setMenu] = useState<MenuType>('뱅킹');

  const mutation = useMutation({
    mutationFn: logout,
    onSuccess: () => {
      window.alert('로그아웃 되었습니다.');
      axiosInstance.interceptors.request.clear();
      axiosInstance.interceptors.request.use((config) => { config.headers.memberId = ''; config.headers.apiKey = bankData.apiKey; return config; }, (error) => Promise.reject(error));
      setMemberData({ isLogin: false, member: null });
      router.replace('/');
    },
  });

  const detailMenu = {
    '뱅킹': [
      { title: '입출금 계좌 개설', onPress: () => router.push('/products/ORDINARY_DEPOSIT') },
      { title: '예적금 상품 조회', onPress: () => router.push('/products/TERM_DEPOSIT') },
      { title: '계좌 관리', onPress: () => router.push('/accounts') },
      { title: '이체한도변경', onPress: () => router.push('/accounts') },
      { title: '계좌 비밀번호 변경', onPress: () => router.push('/accounts') },
    ],
    '이체': [
      { title: '이체', onPress: () => router.push('/accounts') },
      { title: '이체결과 조회', onPress: () => router.push('/accounts') },
      { title: '이체한도 조회/변경', onPress: () => router.push('/accounts') },
    ],
    '조회': [
      { title: '전체계좌 조회', onPress: () => router.push('/accounts') },
      { title: '통합거래내역 조회', onPress: () => router.push('/accounts') },
      { title: '휴면계좌 조회', onPress: () => router.push('/accounts') },
      { title: '해지계좌 조회', onPress: () => router.push('/accounts') },
    ],
  };

  const filterOnPress = (onPress: () => void) => () => memberData.isLogin ? onPress() : router.push('/');

  return (
    <div className="w-full min-h-screen bg-gray-100">
      <Header menu={[
        { title: 'cog-outline', onPress: () => router.push('/setting') },
        { title: 'close', onPress: () => router.back() },
      ]} />
      <div className="w-full h-32">
        {memberData.isLogin ? (
          <div className="w-full h-full flex flex-col justify-around">
            <div className="w-full px-8 flex flex-row justify-between items-center">
              <div className="flex flex-row items-end gap-2">
                <span className="text-2xl font-bold text-gray-700">{memberData.member?.name}</span>
                <span className="text-lg font-medium text-gray-700">님, 안녕하세요!</span>
              </div>
              <button onClick={() => router.push('/profile')} className="text-gray-400 text-sm cursor-pointer">회원정보수정</button>
            </div>
            <div className="w-full flex flex-row items-center justify-center gap-6">
              <button onClick={() => router.push('/accounts')} className="text-sm font-medium text-gray-700 cursor-pointer">내 계좌 보기</button>
              <span className="text-sm font-medium text-gray-700">|</span>
              <button onClick={() => mutation.mutate()} className="text-sm font-medium text-gray-700 cursor-pointer">로그아웃</button>
            </div>
          </div>
        ) : (
          <div className="w-full h-full flex flex-col justify-center items-center gap-4">
            <span className="text-lg font-medium text-gray-700">로그인이 필요한 서비스입니다.</span>
            <div className="flex flex-row gap-6">
              <button onClick={() => router.push('/')} className="text-sm font-medium text-gray-700 cursor-pointer">로그인</button>
              <span className="text-sm font-medium text-gray-700">|</span>
              <button onClick={() => router.push('/join')} className="text-sm font-medium text-gray-700 cursor-pointer">회원가입</button>
            </div>
          </div>
        )}
      </div>
      <div className="w-full h-14 border-4 border-gray-300 flex flex-row items-center px-4">
        <MdSearch size={40} className="text-gray-700" />
        <input className="px-4 text-xl font-bold text-gray-700 outline-none bg-transparent placeholder:text-gray-700" placeholder="메뉴를 검색해보세요." onChange={(e) => setKeyword(e.target.value)} value={keyword} />
      </div>
      <div className="w-full flex-grow flex flex-row min-h-[300px]">
        <div className="w-28 bg-gray-200 py-4">
          {(['뱅킹', '이체', '조회'] as MenuType[]).map((m) => (
            <div key={m} className="w-full h-16 flex items-center">
              <button onClick={() => setMenu(m)}
                className={clsx('ml-4 px-4 py-2 rounded-full cursor-pointer', menu === m && 'bg-pink-200 shadow-sm')}>
                <span className="text-xl font-medium text-gray-700">{m}</span>
              </button>
            </div>
          ))}
        </div>
        <div className="flex-grow overflow-auto">
          <div className="w-full py-4">
            {detailMenu[menu].map((m) => (
              <div key={m.title} className="w-full h-16 flex items-center">
                <button onClick={filterOnPress(m.onPress)} className="px-2 pl-12 py-2 cursor-pointer">
                  <span className="text-lg font-medium text-gray-700">{m.title}</span>
                </button>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
