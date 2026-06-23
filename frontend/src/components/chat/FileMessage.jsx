import React from 'react';
import { Download, Play, FileText, Image, Music } from 'lucide-react';
import clsx from 'clsx';

export default function FileMessage({ message, isOwn }) {
  const files = message.files || [];
  if (!files.length) return null;

  return (
    <div className="space-y-2 mb-2">
      {files.map((file) => {
        const isImg   = file.type?.startsWith('image');
        const isVideo = file.type?.startsWith('video');
        const isAudio = file.type?.startsWith('audio');
        const isPdf   = file.type?.includes('pdf');

        if (isImg) {
          return (
            <a key={file.id} href={file.url} target="_blank" rel="noreferrer">
              <img
                src={file.url} alt={file.name}
                className="max-w-xs rounded-xl object-cover cursor-pointer hover:opacity-90 transition-opacity"
                style={{ maxHeight: 240 }}
              />
            </a>
          );
        }

        if (isVideo) {
          return (
            <div key={file.id} className="max-w-xs rounded-xl overflow-hidden">
              <video src={file.url} controls className="w-full rounded-xl" style={{ maxHeight:200 }}/>
            </div>
          );
        }

        if (isAudio) {
          return (
            <div key={file.id} className={clsx('flex items-center gap-3 p-3 rounded-xl max-w-xs', isOwn ? 'bg-brand-700' : 'bg-gray-100 dark:bg-gray-700')}>
              <div className="w-8 h-8 rounded-full bg-white/20 flex items-center justify-center flex-shrink-0">
                <Music size={14} className={isOwn ? 'text-white' : 'text-brand-600'}/>
              </div>
              <audio src={file.url} controls className="flex-1 h-8" style={{ minWidth:120 }}/>
            </div>
          );
        }

        // Generic file
        return (
          <a key={file.id} href={file.url} target="_blank" rel="noreferrer" download
            className={clsx('flex items-center gap-3 p-3 rounded-xl max-w-xs hover:opacity-90 transition-opacity',
              isOwn ? 'bg-brand-700' : 'bg-gray-100 dark:bg-gray-700')}>
            <div className="w-9 h-9 rounded-lg bg-white/20 flex items-center justify-center flex-shrink-0">
              {isPdf ? <FileText size={16} className={isOwn?'text-red-300':'text-red-500'}/> : <Download size={16} className={isOwn?'text-white':'text-gray-500'}/>}
            </div>
            <div className="flex-1 min-w-0">
              <p className={clsx('text-xs font-medium truncate', isOwn?'text-white':'text-gray-800 dark:text-white')}>{file.name}</p>
              <p className={clsx('text-xs', isOwn?'text-brand-200':'text-gray-400')}>{formatBytes(file.size)}</p>
            </div>
            <Download size={13} className={isOwn?'text-brand-200 flex-shrink-0':'text-gray-400 flex-shrink-0'}/>
          </a>
        );
      })}
    </div>
  );
}

function formatBytes(bytes) {
  if (!bytes) return '';
  if (bytes < 1024) return bytes + ' B';
  if (bytes < 1024*1024) return (bytes/1024).toFixed(1) + ' KB';
  return (bytes/1024/1024).toFixed(1) + ' MB';
}
