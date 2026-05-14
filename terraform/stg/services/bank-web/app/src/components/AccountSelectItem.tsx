import { IAccount } from '@/models';
import { MdAccountCircle } from 'react-icons/md';

interface IProps {
  account: IAccount;
  onPress?: () => void;
}

export default function AccountSelectItem({ account, onPress }: IProps) {
  return (
    <div className="h-24 w-full flex flex-row items-center px-8 gap-6">
      <div className="w-14 h-14 bg-gray-400 rounded-full flex justify-center items-center">
        <MdAccountCircle size={35} className="text-gray-200" />
      </div>
      <button onClick={onPress} className="flex-grow flex flex-col gap-1 text-left cursor-pointer">
        <span className="text-base font-bold text-gray-700">{account?.nickname}</span>
        <span className="text-sm font-normal text-gray-400">{account?.accountId}</span>
      </button>
    </div>
  );
}
