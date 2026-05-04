'use client';
import { useState } from 'react';

interface IProps {
  data: any[];
  labelField: string;
  valueField: string;
  search: boolean;
  placeholder: string;
  value: any;
  setValue: (value: any) => void;
}

export default function DropdownInput({
  data,
  labelField,
  valueField,
  search,
  placeholder,
  value,
  setValue,
}: IProps) {
  const [isOpen, setIsOpen] = useState(false);
  const [query, setQuery] = useState('');

  const selectedItem = data.find((item) => item[valueField] === value);
  const filteredData = search && query
    ? data.filter((item) =>
        String(item[labelField]).toLowerCase().includes(query.toLowerCase())
      )
    : data;

  return (
    <div className="w-full py-4 relative">
      <button
        onClick={() => setIsOpen(!isOpen)}
        className="w-full h-[50px] border border-gray-400 rounded-lg px-3 flex items-center justify-between cursor-pointer bg-white"
      >
        <span className={selectedItem ? 'text-gray-700' : 'text-gray-400'}>
          {selectedItem ? selectedItem[labelField] : placeholder}
        </span>
        <span className="text-gray-400">▼</span>
      </button>
      {isOpen && (
        <div className="absolute top-full left-0 w-full bg-white border border-gray-300 rounded-lg shadow-lg z-10 max-h-[300px] overflow-auto">
          {search && (
            <input
              className="w-full p-2 border-b border-gray-200 outline-none text-gray-700"
              placeholder="Search..."
              value={query}
              onChange={(e) => setQuery(e.target.value)}
            />
          )}
          {filteredData.map((item) => (
            <button
              key={item[valueField]}
              onClick={() => {
                setValue(item[valueField]);
                setIsOpen(false);
                setQuery('');
              }}
              className="w-full p-3 text-left hover:bg-pink-50 cursor-pointer text-gray-700"
            >
              {item[labelField]}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
