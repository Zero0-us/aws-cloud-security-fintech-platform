interface IProps {
  title: string;
  onPress?: () => void;
}

export default function BottomButton({ title, onPress }: IProps) {
  return (
    <button
      onClick={onPress}
      className="w-full h-16 fixed bottom-0 left-0 bg-pink-200 flex items-center justify-center shadow-md cursor-pointer z-50"
    >
      <span className="text-2xl font-semibold text-gray-700">{title}</span>
    </button>
  );
}
