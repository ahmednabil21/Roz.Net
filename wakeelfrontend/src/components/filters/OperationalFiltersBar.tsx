import React from 'react';
import { MapPin, Radio } from 'lucide-react';
import { AgentRegion, AgentReseller } from '../../types';
import {
  getResellerServiceTypeLabel,
  OPERATIONAL_FILTER_CHIP_BASE,
  OPERATIONAL_FILTER_CHIP_INACTIVE,
  OPERATIONAL_FILTER_CHIP_REGION_ACTIVE,
  OPERATIONAL_FILTER_CHIP_RESELLER_ACTIVE,
  OPERATIONAL_FILTER_ROW,
} from '../../utils/operationalFilters';

export type OperationalFiltersBarProps = {
  regions: AgentRegion[];
  resellers: AgentReseller[];
  selectedRegionId: string;
  selectedResellerId: string;
  onRegionSelect: (regionId: string) => void;
  onResellerSelect: (resellerId: string) => void;
  showResellerServiceType?: boolean;
  className?: string;
};

const OperationalFiltersBar: React.FC<OperationalFiltersBarProps> = ({
  regions,
  resellers,
  selectedRegionId,
  selectedResellerId,
  onRegionSelect,
  onResellerSelect,
  showResellerServiceType = true,
  className = '',
}) => {
  if (regions.length === 0 && resellers.length === 0) return null;

  return (
    <div className={`space-y-3 ${className}`}>
      {regions.length > 0 && (
        <div>
          <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-gray-700 dark:text-gray-300">
            <MapPin className="h-4 w-4 text-primary-600 dark:text-primary-400" />
            <span>فلترة المناطق</span>
          </div>
          <div className={OPERATIONAL_FILTER_ROW}>
            <button
              type="button"
              onClick={() => onRegionSelect('')}
              className={`${OPERATIONAL_FILTER_CHIP_BASE} ${
                !selectedRegionId ? OPERATIONAL_FILTER_CHIP_REGION_ACTIVE : OPERATIONAL_FILTER_CHIP_INACTIVE
              }`}
            >
              <MapPin
                className={`h-4 w-4 shrink-0 ${!selectedRegionId ? 'text-white' : 'text-primary-500'}`}
              />
              <div className="min-w-0">
                <div className="text-sm font-semibold truncate">الكل</div>
                <div className={`text-xs truncate ${!selectedRegionId ? 'text-white/80' : 'opacity-70'}`}>
                  كل المناطق
                </div>
              </div>
            </button>
            {regions.map((region) => {
              const active = selectedRegionId === region.id;
              return (
                <button
                  key={region.id}
                  type="button"
                  onClick={() => onRegionSelect(region.id)}
                  title={region.name}
                  className={`${OPERATIONAL_FILTER_CHIP_BASE} ${
                    active ? OPERATIONAL_FILTER_CHIP_REGION_ACTIVE : OPERATIONAL_FILTER_CHIP_INACTIVE
                  }`}
                >
                  <MapPin className={`h-4 w-4 shrink-0 ${active ? 'text-white' : 'text-primary-500'}`} />
                  <div className="min-w-0">
                    <div className="text-sm font-semibold truncate">{region.name}</div>
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}

      {resellers.length > 0 && (
        <div>
          <div className="mb-2 flex items-center gap-2 text-sm font-semibold text-gray-700 dark:text-gray-300">
            <Radio className="h-4 w-4 text-emerald-600 dark:text-emerald-400" />
            <span>فلترة الرسيلرز</span>
          </div>
          <div className={OPERATIONAL_FILTER_ROW}>
            <button
              type="button"
              onClick={() => onResellerSelect('')}
              className={`${OPERATIONAL_FILTER_CHIP_BASE} ${
                !selectedResellerId ? OPERATIONAL_FILTER_CHIP_RESELLER_ACTIVE : OPERATIONAL_FILTER_CHIP_INACTIVE
              }`}
            >
              <Radio
                className={`h-4 w-4 shrink-0 ${!selectedResellerId ? 'text-white' : 'text-emerald-500'}`}
              />
              <div className="min-w-0">
                <div className="text-sm font-semibold truncate">الكل</div>
                <div className={`text-xs truncate ${!selectedResellerId ? 'text-white/80' : 'opacity-70'}`}>
                  كل الرسيلرز
                </div>
              </div>
            </button>
            {resellers.map((reseller) => {
              const active = selectedResellerId === reseller.id;
              return (
                <button
                  key={reseller.id}
                  type="button"
                  onClick={() => onResellerSelect(reseller.id)}
                  title={reseller.name}
                  className={`${OPERATIONAL_FILTER_CHIP_BASE} ${
                    active ? OPERATIONAL_FILTER_CHIP_RESELLER_ACTIVE : OPERATIONAL_FILTER_CHIP_INACTIVE
                  }`}
                >
                  <Radio className={`h-4 w-4 shrink-0 ${active ? 'text-white' : 'text-emerald-500'}`} />
                  <div className="min-w-0">
                    <div className="text-sm font-semibold truncate">{reseller.name}</div>
                    {showResellerServiceType && (
                      <div className={`text-xs truncate ${active ? 'text-white/80' : 'opacity-70'}`}>
                        {getResellerServiceTypeLabel(reseller.serviceType)}
                      </div>
                    )}
                  </div>
                </button>
              );
            })}
          </div>
        </div>
      )}
    </div>
  );
};

export default OperationalFiltersBar;
