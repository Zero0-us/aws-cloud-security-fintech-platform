interface IProps {
  label: string;
  children?: React.ReactNode;
}

export default function CommonInput({ label, children }: IProps) {
  return (
    <div className="w-full px-6 py-8 relative">
      <span className="text-lg font-semibold text-slate-700">{label}</span>
      {children || (
        <input className="w-full border-b border-gray-800/50 text-gray-700 outline-none bg-transparent" />
      )}
    </div>
  );
}
