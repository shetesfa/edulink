import React from 'react';

export default function LoadingScreen() {
  return (
    <div className="fixed inset-0 bg-[#1E1B4B] flex items-center justify-center z-50">
      <div className="text-center">
        <div className="w-16 h-16 bg-gradient-to-br from-violet-500 to-amber-500 rounded-2xl flex items-center justify-center mx-auto mb-4">
          <span className="font-display font-black text-2xl text-white">E</span>
        </div>
        <div className="flex gap-1.5 justify-center">
          {[0, 1, 2].map((i) => (
            <div key={i} className="w-2 h-2 bg-violet-400 rounded-full animate-bounce"
              style={{ animationDelay: `${i * 0.15}s` }}/>
          ))}
        </div>
      </div>
    </div>
  );
}
