import React from 'react';

export const DownloadButtons: React.FC = () => {
    return (
        <div className="flex flex-wrap gap-3 items-center justify-center">
            {/* Google Play Button */}
            <a
                href="#"
                className="group flex items-center gap-2.5 bg-white/[0.03] border border-white/[0.08] px-5 py-2 rounded-xl hover:bg-white/[0.08] transition-all duration-300 active:scale-95"
            >
                <svg viewBox="0 0 24 24" className="w-5 h-5" xmlns="http://www.w3.org/2000/svg">
                    <path d="M3 20.5v-17c0-.9 1-1.4 1.7-.9l15.3 8.5c.7.4.7 1.4 0 1.8l-15.3 8.5c-.7.5-1.7 0-1.7-.9z" fill="#0094FF" />
                    <path d="M16 12L3 4.5v15L16 12z" fill="white" fillOpacity="0.2" />
                </svg>
                <div className="text-left">
                    <p className="text-[8px] font-black uppercase tracking-widest text-zinc-500 group-hover:text-primary transition-colors">Disponible en</p>
                    <p className="text-xs font-black tracking-tight text-white leading-tight">Google Play</p>
                </div>
            </a>

            {/* App Store Button */}
            <a
                href="#"
                className="group flex items-center gap-2.5 bg-white/[0.03] border border-white/[0.08] px-5 py-2 rounded-xl hover:bg-white/[0.08] transition-all duration-300 active:scale-95"
            >
                <svg viewBox="0 0 24 24" className="w-5 h-5" xmlns="http://www.w3.org/2000/svg">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2.01.77-3.27.82-1.31.05-2.31-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91 1.65.07 2.49.52 3.01.99.11.11.23.23.33.36-1.3.77-2.13 2.1-2.09 3.63.04 1.88 1.58 3.32 3.44 3.42-.04.42-.1.85-.2 1.25zM12.91 5.99c.35-1.5 1.77-2.61 3.35-2.6.14 1.58-1.28 3.16-3.35 3.1-.14-1.58-.2-2.5.3-3.1z" fill="white" />
                </svg>
                <div className="text-left">
                    <p className="text-[8px] font-black uppercase tracking-widest text-zinc-500 group-hover:text-primary transition-colors">Consíguelo en</p>
                    <p className="text-xs font-black tracking-tight text-white leading-tight">App Store</p>
                </div>
            </a>
        </div>
    );
};
