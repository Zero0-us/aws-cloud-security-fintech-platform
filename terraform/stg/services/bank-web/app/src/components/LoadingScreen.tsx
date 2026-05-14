interface IProps {
  isLoading: boolean;
}

export default function LoadingScreen({ isLoading }: IProps) {
  if (!isLoading) return null;
  return (
    <div className="fixed inset-0 z-50 flex justify-center items-center bg-gray-950/30">
      <div className="w-12 h-12 border-4 border-white border-t-transparent rounded-full animate-spin" />
    </div>
  );
}
