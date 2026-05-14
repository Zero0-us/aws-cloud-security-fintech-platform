'use client';
import { memberDataAtom } from '@/store/atoms';
import { useRecoilValue } from 'recoil';
import { useEffect } from 'react';
import { axiosInstance } from '@/api';

export default function Interceptor({ children }: { children: React.ReactNode }) {
  const memberData = useRecoilValue(memberDataAtom);

  useEffect(() => {
    const id = axiosInstance.interceptors.request.use(
      (config) => {
        if (memberData.isLogin && memberData.member) {
          config.headers.memberId = memberData.member.id;
        } else {
          config.headers.memberId = '';
        }
        return config;
      },
      (error) => Promise.reject(error)
    );
    return () => axiosInstance.interceptors.request.eject(id);
  }, [memberData]);

  return <>{children}</>;
}
