import React, { useRef, useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import {
  Upload,
  Download,
  FileSpreadsheet,
  CheckCircle,
  XCircle,
  AlertTriangle,
  Loader2,
  X,
} from 'lucide-react';
import { apiService, ApiService } from '../services/api';
import { ExcelImportResponse } from '../types';
import { showError, showSuccess } from '../utils/notifications';

type Props = {
  open: boolean;
  onClose: () => void;
  regionId: string;
  resellerId: string;
  regionName?: string;
  resellerName?: string;
  agentId?: string;
  onImported?: () => void;
};

const SubscriberRegionExcelImport: React.FC<Props> = ({
  open,
  onClose,
  regionId,
  resellerId,
  regionName,
  resellerName,
  agentId,
  onImported,
}) => {
  const fileInputRef = useRef<HTMLInputElement>(null);
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [importResult, setImportResult] = useState<ExcelImportResponse | null>(null);
  const [downloadingTemplate, setDownloadingTemplate] = useState(false);

  const importMutation = useMutation({
    mutationFn: async (file: File) =>
      apiService.importSubscribersRegionFromExcel(file, regionId, resellerId, agentId),
    onSuccess: (data) => {
      setImportResult(data);
      const successCount = data.successCount ?? 0;
      const errorCount = data.errorCount ?? 0;
      if (successCount > 0) {
        showSuccess('تم الاستيراد', data.message);
        onImported?.();
        if (errorCount === 0) {
          setSelectedFile(null);
          if (fileInputRef.current) fileInputRef.current.value = '';
        }
      }
    },
    onError: (error: unknown) => {
      showError('فشل الاستيراد', ApiService.showError(error));
    },
  });

  const handleDownloadTemplate = async () => {
    setDownloadingTemplate(true);
    try {
      const blob = await apiService.downloadSubscribersRegionExcelTemplate();
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = 'SubscribersRegionTemplate.xlsx';
      link.click();
      URL.revokeObjectURL(url);
    } catch (error) {
      showError('خطأ', ApiService.showError(error));
    } finally {
      setDownloadingTemplate(false);
    }
  };

  const handleFileSelect = (event: React.ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    if (!file) return;

    if (!file.name.endsWith('.xlsx') && !file.name.endsWith('.xls')) {
      showError('ملف غير مدعوم', 'يرجى اختيار ملف Excel (.xlsx أو .xls)');
      return;
    }

    setSelectedFile(file);
    setImportResult(null);
  };

  const handleImport = () => {
    if (!selectedFile) {
      showError('لم يُختر ملف', 'يرجى اختيار ملف Excel أولاً');
      return;
    }
    importMutation.mutate(selectedFile);
  };

  const handleClose = () => {
    if (importMutation.isPending) return;
    setSelectedFile(null);
    setImportResult(null);
    if (fileInputRef.current) fileInputRef.current.value = '';
    onClose();
  };

  if (!open) return null;

  const canImport = !!regionId && !!resellerId;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50" onClick={handleClose}>
      <div
        className="bg-white dark:bg-gray-800 rounded-xl shadow-xl w-full max-w-lg max-h-[90vh] overflow-y-auto"
        onClick={(e) => e.stopPropagation()}
      >
        <div className="flex items-center justify-between p-4 border-b border-gray-200 dark:border-gray-700">
          <div className="flex items-center gap-2">
            <FileSpreadsheet className="h-5 w-5 text-primary-600" />
            <h2 className="text-lg font-semibold text-gray-900 dark:text-white">استيراد مشتركين من Excel</h2>
          </div>
          <button
            type="button"
            onClick={handleClose}
            disabled={importMutation.isPending}
            className="p-2 rounded-lg hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-500"
          >
            <X className="h-5 w-5" />
          </button>
        </div>

        <div className="p-4 space-y-4">
          <div className="rounded-lg bg-gray-50 dark:bg-gray-900/50 p-3 text-sm space-y-1">
            <p className="text-gray-700 dark:text-gray-300">
              <span className="font-medium">المنطقة:</span>{' '}
              {regionName || (regionId ? regionId : '— غير محددة —')}
            </p>
            <p className="text-gray-700 dark:text-gray-300">
              <span className="font-medium">الرسيلر:</span>{' '}
              {resellerName || (resellerId ? resellerId : '— غير محدد —')}
            </p>
          </div>

          {!canImport && (
            <div className="flex items-start gap-2 p-3 rounded-lg bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200 text-sm">
              <AlertTriangle className="h-5 w-5 shrink-0 mt-0.5" />
              <p>يرجى اختيار المنطقة والرسيلر من البطاقات أعلى الصفحة قبل الاستيراد.</p>
            </div>
          )}

          <p className="text-sm text-gray-600 dark:text-gray-400">
            الأعمدة: معرف الاشتراك، المشترك، اسم المستخدم، منطقة المشترك
          </p>

          <button
            type="button"
            onClick={handleDownloadTemplate}
            disabled={downloadingTemplate}
            className="flex items-center gap-2 px-4 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-700 dark:text-gray-200 w-full justify-center min-h-[44px]"
          >
            {downloadingTemplate ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <Download className="h-4 w-4" />
            )}
            <span>تحميل قالب Excel</span>
          </button>

          <div>
            <input
              ref={fileInputRef}
              type="file"
              accept=".xlsx,.xls"
              onChange={handleFileSelect}
              className="hidden"
              id="subscriber-region-excel-file"
            />
            <label
              htmlFor="subscriber-region-excel-file"
              className="flex flex-col items-center justify-center gap-2 p-6 border-2 border-dashed border-gray-300 dark:border-gray-600 rounded-lg cursor-pointer hover:border-primary-500 hover:bg-primary-50/50 dark:hover:bg-primary-900/10 transition-colors"
            >
              <Upload className="h-8 w-8 text-gray-400" />
              <span className="text-sm text-gray-600 dark:text-gray-400">
                {selectedFile ? selectedFile.name : 'اضغط لاختيار ملف Excel'}
              </span>
            </label>
          </div>

          {importResult && (
            <div
              className={`p-3 rounded-lg text-sm ${
                (importResult.errorCount ?? 0) === 0
                  ? 'bg-green-50 dark:bg-green-900/20 text-green-800 dark:text-green-200'
                  : 'bg-amber-50 dark:bg-amber-900/20 text-amber-800 dark:text-amber-200'
              }`}
            >
              <div className="flex items-center gap-2 font-medium mb-2">
                {(importResult.errorCount ?? 0) === 0 ? (
                  <CheckCircle className="h-4 w-4" />
                ) : (
                  <AlertTriangle className="h-4 w-4" />
                )}
                <span>{importResult.message}</span>
              </div>
              {(importResult.importedCount ?? 0) > 0 && (
                <p>جديد: {importResult.importedCount}</p>
              )}
              {(importResult.updatedCount ?? 0) > 0 && (
                <p>محدَّث: {importResult.updatedCount}</p>
              )}
              {importResult.errors && importResult.errors.length > 0 && (
                <ul className="mt-2 space-y-1 max-h-32 overflow-y-auto">
                  {importResult.errors.slice(0, 10).map((err, i) => (
                    <li key={i} className="flex items-start gap-1">
                      <XCircle className="h-3 w-3 shrink-0 mt-0.5" />
                      <span>{err}</span>
                    </li>
                  ))}
                  {importResult.errors.length > 10 && (
                    <li className="text-xs opacity-75">... و{importResult.errors.length - 10} أخطاء أخرى</li>
                  )}
                </ul>
              )}
            </div>
          )}

          <div className="flex gap-2 pt-2">
            <button
              type="button"
              onClick={handleClose}
              disabled={importMutation.isPending}
              className="flex-1 px-4 py-2.5 border border-gray-300 dark:border-gray-600 rounded-lg text-gray-700 dark:text-gray-200 hover:bg-gray-50 dark:hover:bg-gray-700 min-h-[44px]"
            >
              إغلاق
            </button>
            <button
              type="button"
              onClick={handleImport}
              disabled={!canImport || !selectedFile || importMutation.isPending}
              className="flex-1 flex items-center justify-center gap-2 px-4 py-2.5 bg-primary-600 hover:bg-primary-700 text-white rounded-lg disabled:opacity-50 disabled:cursor-not-allowed min-h-[44px]"
            >
              {importMutation.isPending ? (
                <>
                  <Loader2 className="h-4 w-4 animate-spin" />
                  <span>جاري الاستيراد...</span>
                </>
              ) : (
                <>
                  <Upload className="h-4 w-4" />
                  <span>استيراد</span>
                </>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};

export default SubscriberRegionExcelImport;
