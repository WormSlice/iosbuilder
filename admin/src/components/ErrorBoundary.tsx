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
        <div className="min-h-screen bg-[#F8FAFC] flex items-center justify-center p-6">
          <div className="max-w-md w-full bg-white border border-slate-200 rounded-xl p-6 text-center space-y-5 shadow-sm">
            <div className="w-12 h-12 bg-red-50 text-red-600 rounded-xl flex items-center justify-center mx-auto border border-red-200">
              <AlertTriangle size={24} />
            </div>

            <div className="space-y-1">
              <h1 className="text-base font-bold text-slate-900">
                Inconsistencia Detectada
              </h1>
              <p className="text-xs text-slate-500">
                Se detectó un error al procesar este módulo. El resto del panel administrativo sigue disponible.
              </p>
            </div>

            <div className="bg-slate-50 border border-slate-200 p-3.5 rounded-lg text-left">
              <p className="text-[10px] font-bold text-red-600 uppercase tracking-wider mb-1">Detalle del Error</p>
              <p className="text-xs font-mono text-slate-700 break-words">
                {this.state.error?.message || 'Error de componente desconocido'}
              </p>
            </div>

            <div className="flex items-center justify-center gap-2 pt-2">
              <button
                onClick={() => window.location.reload()}
                className="btn-primary text-xs flex items-center gap-1.5"
              >
                <RefreshCw size={13} />
                <span>Reintentar</span>
              </button>

              <button
                onClick={() => {
                  this.setState({ hasError: false });
                  window.location.href = '/admin/dashboard';
                }}
                className="btn-secondary text-xs flex items-center gap-1.5"
              >
                <Home size={13} />
                <span>Ir al Dashboard</span>
              </button>
            </div>

            <p className="text-[10px] text-slate-400 font-mono pt-2 border-t border-slate-100">
              CONNECT Admin • Error Handler
            </p>
          </div>
        </div>
      );
    }

    return this.props.children;
  }
}
