import { IProduct } from '@/models/product';
import { getProductTypeName } from '@/utils';

interface IProps {
  product: IProduct;
  link: () => void;
}

export default function ProductListItem({ product, link }: IProps) {
  return (
    <div className="w-full h-40 flex flex-row py-4 px-8 bg-gray-50">
      <div className="flex-grow flex flex-col gap-2">
        <div className="w-full flex flex-row">
          <div className="border border-pink-300 px-2 py-1 rounded-lg">
            <span className="text-sm text-pink-400 font-semibold">
              {getProductTypeName(product.productType)!.title}
            </span>
          </div>
        </div>
        <div className="w-full flex flex-col gap-2">
          <span className="text-xl font-bold text-gray-700">{product.name}</span>
          <span className="text-md font-medium w-52 overflow-hidden text-ellipsis whitespace-nowrap text-gray-700">
            {product.description}
          </span>
        </div>
      </div>
      <div className="w-20 flex flex-col justify-between">
        <div className="w-20 h-20 border rounded-full flex flex-col justify-center items-center border-pink-500">
          <span className="text-xs text-gray-600">최고 연</span>
          <span className="text-xl font-bold text-pink-800">{`${product.rate}%`}</span>
        </div>
        <div className="w-full flex flex-row justify-end">
          <button onClick={link} className="px-2 py-1 bg-pink-300 rounded-lg cursor-pointer">
            <span className="text-sm text-white font-semibold">가입하기</span>
          </button>
        </div>
      </div>
    </div>
  );
}
