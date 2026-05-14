import { IMember } from '@/models';
import { AtomEffect, atom } from 'recoil';

const JOABANK_BANKID = typeof window !== 'undefined'
  ? process.env.NEXT_PUBLIC_JOABANK_BANKID || ''
  : '';
const API_KEY = typeof window !== 'undefined'
  ? process.env.NEXT_PUBLIC_API_KEY || ''
  : '';

interface IMemberData {
  isLogin: boolean;
  member: IMember | null;
}

interface IBankData {
  bankId: string;
  bankName: string;
  apiKey: string;
}

const defaultMemberData: IMemberData = {
  isLogin: false,
  member: null,
};

const defaultBankData: IBankData = {
  bankId: JOABANK_BANKID,
  bankName: '조아은행',
  apiKey: API_KEY,
};

export const persistAtom =
  <T>(key: string): AtomEffect<T> =>
  ({ setSelf, onSet, trigger }) => {
    const loadPersisted = () => {
      if (typeof window === 'undefined') return;
      const savedValue = localStorage.getItem(key);
      if (savedValue != null) {
        setSelf(JSON.parse(savedValue));
      }
    };

    if (trigger === 'get') {
      loadPersisted();
    }

    onSet((newValue, _, isReset) => {
      if (typeof window === 'undefined') return;
      isReset
        ? localStorage.removeItem(key)
        : localStorage.setItem(key, JSON.stringify(newValue));
    });
  };

export const memberDataAtom = atom<IMemberData>({
  key: 'memberData',
  default: defaultMemberData,
  effects: [persistAtom('memberData')],
});

export const bankDataAtom = atom<IBankData>({
  key: 'bankData',
  default: defaultBankData,
  effects: [persistAtom('bankData')],
});
