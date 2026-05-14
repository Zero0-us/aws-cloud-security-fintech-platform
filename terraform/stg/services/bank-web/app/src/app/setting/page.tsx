'use client';
import { useRouter } from 'next/navigation';
import Header from '@/components/Header';
import CommonMenuItem from '@/components/CommonMenuItem';

export default function SettingPage() {
  const router = useRouter();

  return (
    <div className="w-full min-h-screen bg-gray-100 flex flex-col">
      <Header stack="설정" goBack={() => router.push('/main')} menu={[
        { title: 'home-outline', onPress: () => router.push('/main') },
        { title: 'menu', onPress: () => router.push('/menu') },
      ]} />
      <div className="overflow-auto flex-grow">
        <CommonMenuItem title="알림설정" underline />
        <CommonMenuItem title="앱 환경설정" underline />
        <CommonMenuItem title="은행코드 변경 (관리자 전용)" underline onPress={() => router.push('/profile/change-bank')} />
      </div>
    </div>
  );
}
