import React from 'react';

interface WorkInProgressProps {
    feature?: string;
}

export const WorkInProgress: React.FC<WorkInProgressProps> = ({ feature }) => {
    return (
        <div className="inline-flex items-center gap-2 bg-yellow-50 text-yellow-700 px-3 py-1 rounded-full border border-yellow-100 mt-2">
            <div className="w-2 h-2 bg-yellow-400 rounded-full animate-pulse"></div>
            <span className="text-[10px] font-black uppercase tracking-widest">Trabajando en esto</span>
        </div>
    );
};
