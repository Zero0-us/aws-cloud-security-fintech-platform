import { IAccount } from '@/models';
import { formatAmount } from '@/utils';
import { MdChevronRight } from 'react-icons/md';

interface IProps {
  account: IAccount;
  link: () => void;
}

export default function AccountListItem({ account, link }: IProps) {
  return (
    <div className="h-36 w-full flex flex-col justify-center p-4 bg-pink-100 rounded-xl gap-2 shadow-sm">
      <div className="w-full flex flex-row justify-between">
        <span className="text-lg font-semibold text-gray-700">{account.nickname}</span>
        <div className="bg-pink-200 px-2 h-8 flex justify-center items-center rounded-2xl">
          <span className="text-sm font-semibold text-gray-700">
            {account.amount > 0 ? '예적금상품' : '입출금통장'}
          </span>
        </div>
      </div>
      <span className="text-sm font-normal text-gray-400">{account.accountId}</span>
      <div className="w-full flex flex-row justify-between items-center">
        <span className="text-xl font-bold text-gray-700">{`${formatAmount(account.balance)}원`}</span>
        <button onClick={link} className="cursor-pointer">
          <MdChevronRight size={25} className="text-gray-500" />
        </button>
      </div>
    </div>
  );
}
