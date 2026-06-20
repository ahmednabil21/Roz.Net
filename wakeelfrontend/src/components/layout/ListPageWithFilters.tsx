import React from 'react';

type ListPageWithFiltersProps = {
  sidebar?: React.ReactNode;
  children: React.ReactNode;
};

/** تخطيط قائمة: فلترة المناطق/الرسيلرز أفقياً فوق المحتوى. */
const ListPageWithFilters: React.FC<ListPageWithFiltersProps> = ({ sidebar, children }) => {
  if (!sidebar) {
    return <>{children}</>;
  }

  return (
    <div className="space-y-4">
      <div className="rounded-2xl border border-gray-200/80 dark:border-gray-700/80 bg-white/80 dark:bg-gray-900/50 backdrop-blur-sm shadow-sm p-3 sm:p-4">
        {sidebar}
      </div>
      <div className="min-w-0">{children}</div>
    </div>
  );
};

export default ListPageWithFilters;
