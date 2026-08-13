import React, { useState } from 'react';
import { apiService } from '../services/api';

type TaskCompletionImageProps = {
  url?: string | null;
  className?: string;
};

const TaskCompletionImage: React.FC<TaskCompletionImageProps> = ({ url, className }) => {
  const [failed, setFailed] = useState(false);
  const src = apiService.resolvePublicFileUrl(url);
  if (!src || failed) return null;

  return (
    <div className={className ?? 'rounded-md border border-gray-200 dark:border-gray-700 p-3'}>
      <p className="text-gray-500 dark:text-gray-400 text-sm">صورة إكمال المهمة</p>
      <a href={src} target="_blank" rel="noreferrer" className="block mt-2">
        <img
          src={src}
          alt="صورة إكمال المهمة"
          className="w-full max-h-80 object-contain rounded-md bg-gray-50 dark:bg-gray-900"
          onError={() => setFailed(true)}
        />
      </a>
    </div>
  );
};

export default TaskCompletionImage;
