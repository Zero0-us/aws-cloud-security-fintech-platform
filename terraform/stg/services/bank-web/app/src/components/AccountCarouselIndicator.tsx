interface IProps {
  total: number;
  current: number;
}

export default function AccountCarouselIndicator({ total, current }: IProps) {
  return (
    <div className="absolute bottom-2 w-full h-6 flex flex-row gap-1 justify-center items-center">
      {[...Array(total).keys()].map((page) =>
        page === current ? (
          <div className="bg-slate-500 w-8 h-1 rounded-lg" key={page} />
        ) : (
          <div className="bg-slate-400 w-1 h-1 rounded-lg" key={page} />
        )
      )}
    </div>
  );
}
