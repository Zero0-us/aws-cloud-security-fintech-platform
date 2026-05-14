import { formatAmount } from '@/utils';

interface IProps {
  date: string;
  title: string;
  amount: number;
  balance?: number;
}

export default function HistoryItem({ date, title, amount, balance }: IProps) {
  return (
    <div className="w-full h-28 border-b border-gray-300 p-4 flex flex-row items-center justify-between">
      <div className="flex flex-row gap-6 items-center">
        <span className="text-sm font-light text-gray-500">
          {date.startsWith(String(new Date().getFullYear()).slice(2, 4))
            ? date.slice(3)
            : date}
        </span>
        <span className="text-lg font-semibold text-gray-700">{title}</span>
      </div>
      <div className="flex flex-col items-end">
        <span className={`text-lg font-semibold ${amount > 0 ? 'text-blue-600' : 'text-red-600'}`}>
          {`${formatAmount(amount)}원`}
        </span>
        {balance !== undefined && (
          <span className="text-sm font-light text-gray-500">
            {`${formatAmount(balance)}원`}
          </span>
        )}
      </div>
    </div>
  );
}
