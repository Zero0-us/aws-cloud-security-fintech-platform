interface IProps {
  children: React.ReactNode;
  close?: () => void;
}

export default function BottomPopup({ children, close }: IProps) {
  return (
    <div className="fixed inset-0 bg-black/30 z-40" onClick={close}>
      <div
        className="w-full absolute bottom-0 rounded-t-[40px] bg-white px-4 py-2 flex flex-col items-center pb-20"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="w-16 h-1 bg-slate-400/50 rounded-full mb-4" />
        {children}
      </div>
    </div>
  );
}
