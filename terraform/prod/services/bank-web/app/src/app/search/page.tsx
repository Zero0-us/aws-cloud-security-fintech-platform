'use client';
import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { MdSearch } from 'react-icons/md';
import Header from '@/components/Header';
import ToggleSwitch from '@/components/ToggleSwitch';

export default function SearchPage() {
  const router = useRouter();
  const [isAutosave, setIsAutosave] = useState(true);
  const [keyword, setKeyword] = useState('');

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="통합검색" goBack={() => router.push('/main')} menu={[
        { title: 'home-outline', onPress: () => router.push('/main') },
        { title: 'menu', onPress: () => router.push('/menu') },
      ]} />
      <div className="w-full h-32 flex flex-row justify-center items-center p-6">
        <div className="flex-grow border-b border-gray-300 flex flex-row items-center justify-between">
          <input placeholder="메뉴, 상품을 찾아보세요" className="text-xl font-medium text-gray-700 outline-none bg-transparent placeholder:text-gray-700" onChange={(e) => setKeyword(e.target.value)} value={keyword} />
          <MdSearch size={30} className="text-black" />
        </div>
      </div>
      <div className="w-full flex-grow overflow-auto">
        <div className="w-full bg-gray-200 flex flex-col gap-6">
          <div className="w-full h-40 bg-gray-100">
            <div className="w-full flex flex-row justify-between items-center px-8">
              <span className="text-xl font-medium text-gray-700">최근검색어</span>
              <div className="flex flex-row items-center gap-1">
                <span className="text-sm font-medium text-gray-700">자동저장</span>
                <ToggleSwitch isEnabled={isAutosave} toggleSwitch={() => setIsAutosave((p) => !p)} />
              </div>
            </div>
            <div className="w-full flex-grow flex justify-center items-center py-12">
              <span className="text-sm font-medium text-gray-700">최근 검색내역이 없습니다.</span>
            </div>
          </div>
          <div className="w-full bg-gray-100">
            <div className="px-10 py-6"><span className="text-xl font-medium text-gray-700">검색결과</span></div>
            <div className="w-full h-40 flex justify-center items-center">
              <span className="text-sm font-medium text-gray-700">검색결과가 없습니다.</span>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
