'use client';
import { bankDataAtom } from '@/store/atoms';
import { useRecoilValue } from 'recoil';
import { MdChevronLeft, MdMenu, MdClose, MdSearch, MdHome, MdSettings } from 'react-icons/md';

interface IMenu {
  title: string;
  onPress: () => void;
}

interface IProps {
  stack?: string;
  goBack?: () => void;
  menu: IMenu[];
}

const iconMap: Record<string, React.ComponentType<{ size: number; className?: string }>> = {
  menu: MdMenu,
  close: MdClose,
  magnify: MdSearch,
  'home-outline': MdHome,
  'cog-outline': MdSettings,
};

export default function Header({ stack, goBack, menu }: IProps) {
  const bankData = useRecoilValue(bankDataAtom);

  return (
    <div className="w-full h-16 flex flex-row justify-between px-4 items-center bg-gray-100">
      <div className="flex flex-row items-center flex-grow">
        {goBack && (
          <button onClick={goBack} className="cursor-pointer">
            <MdChevronLeft size={30} />
          </button>
        )}
        <span className="text-2xl font-semibold text-gray-700">
          {stack || bankData.bankName}
        </span>
      </div>
      <div className="flex flex-row justify-end gap-4 pr-2 items-center">
        {menu.map(m => {
          const Icon = iconMap[m.title];
          return (
            <button key={m.title} onClick={m.onPress} className="cursor-pointer">
              {Icon ? <Icon size={30} /> : <span>{m.title}</span>}
            </button>
          );
        })}
      </div>
    </div>
  );
}
