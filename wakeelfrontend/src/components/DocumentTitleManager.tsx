import React, { useEffect } from 'react';
import { useLocation } from 'react-router-dom';
import { formatDocumentTitle } from '../utils/pageTitles';

const DocumentTitleManager: React.FC = () => {
  const { pathname } = useLocation();

  useEffect(() => {
    document.title = formatDocumentTitle(pathname);
  }, [pathname]);

  return null;
};

export default DocumentTitleManager;
