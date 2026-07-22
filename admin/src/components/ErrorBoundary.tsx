import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertTriangle, RefreshCw, Home } from 'lucide-react';

interface Props {
  children?: ReactNode;
}

interface State {
  hasError: boolean;
  error?: Error;
}

export class ErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="min-h-screen bg-zinc-50 flex items-center justify-center p-8">
          <div className="max-w-md w-full text-center space-y-8 animate-in fade-in zoom-in duration-500">
            <div className="w-24 h-24 bg-red-500/10 rounded-[2.5rem] flex items-center justify-center mx-auto border border-red-500/20">
              <AlertTriangle size={48} className="text-red-500" />
            </div>
            
            <div className="space-y-2">
              <h1 className="text-3xl font-black tracking-tighter text-black uppercase italic">
                SISTEMA EN PAUSA
              </h1>
              <p className="text-zinc-400 text-xs font-bold uppercase tracking-widest leading-relaxed">
                Se detectó una inconsistencia en la renderización de este componente. No te preocupes, el resto del panel sigue operativo.
              </p>
            </div>

            <div className="bg-white border border-zinc-100 p-6 rounded-3xl text-left shadow-sm">
              <p className="text-[10px] font-black text-red-500 uppercase tracking-widest mb-1">Error Identificado</p>
              <p className="text-[11px] font-mono text-zinc-600 break-words leading-relaxed">
                {this.state.error?.message || 'Error de componente desconocido'}
              </p>
            </div>

            <div className="flex flex-col gap-3">
              <button
                onClick={() => window.location.reload()}
                className="w-full py-4 bg-black text-white rounded-2xl font-black text-[10px] uppercase tracking-[0.2em] hover:bg-zinc-800 transition-all flex items-center justify-center gap-3 shadow-lg shadow-black/10"
              >
                <RefreshCw size={14} /> Reiniciar Aplicación
              </button>
              
              <button
                onClick={() => {
                    this.setState({ hasError: false });
                    window.location.href = '/admin/dashboard';
                }}
                className="w-full py-4 bg-white text-black rounded-2xl font-black text-[10px] uppercase tracking-[0.2em] hover:bg-zinc-50 transition-all border border-zinc-200 flex items-center justify-center gap-3"
              >
                <Home size={14} /> Volver al Dashboard
              </button>
            </div>

            <p className="text-[9px] text-zinc-400 font-bold uppercase tracking-[0.3em]">
              CONNECT MASTER SYSTEM • v1.1.0
            </p>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
