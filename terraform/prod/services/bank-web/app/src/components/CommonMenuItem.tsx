import { MdChevronRight } from 'react-icons/md';

interface IProps {
  title: string;
  underline: boolean;
  subtitle?: string;
  onPress?: () => void;
}

export default function CommonMenuItem({ title, underline, subtitle, onPress }: IProps) {
  return (
    <div className="w-full px-6 py-2">
      <div
        onClick={onPress}
        className={`w-full h-16 flex flex-row justify-between items-center cursor-pointer ${
          underline ? 'border-b border-slate-400/50' : ''
        }`}
      >
        <div className="flex flex-col">
          {subtitle && (
            <span className="text-xs font-light text-gray-400">{subtitle}</span>
          )}
          <span className="text-lg font-semibold text-slate-700">{title}</span>
        </div>
        <MdChevronRight size={30} className="text-gray-400" />
      </div>
    </div>
  );
}
