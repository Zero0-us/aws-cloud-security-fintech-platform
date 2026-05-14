import clsx from 'clsx';

interface IOption {
  label: string;
  value: any;
}

interface IProps {
  label: string;
  options: IOption[];
  value: any;
  setValue: (value: any) => void;
}

export default function OptionInput({ label, options, value, setValue }: IProps) {
  return (
    <div className="w-full px-6 py-8 flex flex-col gap-2">
      <span className="text-lg font-semibold text-slate-700">{label}</span>
      <div className="w-full h-12 flex flex-row bg-gray-300">
        {options.map((option) => (
          <button
            key={String(option.value)}
            onClick={() => setValue(option.value)}
            className={clsx(
              'h-full flex-grow flex justify-center items-center border border-gray-400 cursor-pointer',
              option.value === value && 'bg-gray-50',
            )}
          >
            <span className="text-lg font-semibold text-gray-700">{option.label}</span>
          </button>
        ))}
      </div>
    </div>
  );
}
