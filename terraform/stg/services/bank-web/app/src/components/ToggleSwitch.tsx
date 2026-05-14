interface IProps {
  toggleSwitch: () => void;
  isEnabled: boolean;
}

export default function ToggleSwitch({ toggleSwitch, isEnabled }: IProps) {
  return (
    <button
      onClick={toggleSwitch}
      className={`relative w-12 h-6 rounded-full transition-colors cursor-pointer ${
        isEnabled ? 'bg-pink-100' : 'bg-gray-300'
      }`}
    >
      <div
        className={`absolute top-0.5 w-5 h-5 rounded-full transition-transform ${
          isEnabled ? 'translate-x-6 bg-pink-200' : 'translate-x-0.5 bg-gray-400'
        }`}
      />
    </button>
  );
}
