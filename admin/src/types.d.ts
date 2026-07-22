declare namespace JSX {
    interface IntrinsicElements {
        [elemName: string]: any;
    }
}

declare module 'react' {
    export type FC<P = {}> = (props: P) => any;
    export type ReactNode = any;
    export function useState<T>(initialState: T | (() => T)): [T, (newState: T | ((prev: T) => T)) => void];
    export function useEffect(effect: () => (void | (() => void)), deps?: any[]): void;
    export function useMemo<T>(factory: () => T, deps: any[] | undefined): T;
    export function useCallback<T extends (...args: any[]) => any>(callback: T, deps: any[]): T;
    export function useRef<T>(initialValue: T): { current: T };
    export const memo: <T>(component: T) => T;
    export const forwardRef: <T, P = {}>(render: (props: P, ref: any) => any) => T;
    export type FormEvent<T = Element> = any;
    export type HTMLFormElement = any;
}

declare module 'react-dom';
declare module 'react-dom/client';
declare module 'react-router-dom';

declare module 'framer-motion' {
    export const motion: any;
    export const AnimatePresence: any;
    export const LayoutGroup: any;
}

declare module 'lucide-react' {
    import { FC, SVGProps } from 'react';
    interface IconProps extends SVGProps<SVGSVGElement> {
        size?: string | number;
        color?: string;
        strokeWidth?: string | number;
        className?: string;
    }
    export type Icon = FC<IconProps>;
    export const LayoutGrid: Icon;
    export const Users: Icon;
    export const CheckCircle: Icon;
    export const ShieldCheck: Icon;
    export const Zap: Icon;
    export const Megaphone: Icon;
    export const FileText: Icon;
    export const Flag: Icon;
    export const Bell: Icon;
    export const Settings: Icon;
    export const ShoppingBag: Icon;
    export const Edit3: Icon;
    export const Trash2: Icon;
    export const Eye: Icon;
    export const UserX: Icon;
    export const ArrowUpRight: Icon;
    export const Search: Icon;
    export const RefreshCw: Icon;
    export const Filter: Icon;
    export const Rocket: Icon;
    export const ChevronDown: Icon;
    export const ChevronUp: Icon;
    export const MoreVertical: Icon;
    export const Database: Icon;
    export const RotateCcw: Icon;
    export const Download: Icon;
    export const Terminal: Icon;
    export const Activity: Icon;
    export const HardDrive: Icon;
    export const Lock: Icon;
    export const Send: Icon;
    export const User: Icon;
    export const Smartphone: Icon;
    export const Mail: Icon;
    export const Globe: Icon;
    export const AlertCircle: Icon;
    export const ShieldAlert: Icon;
    export const LogOut: Icon;
    export const LogIn: Icon;
    export const Camera: Icon;
    export const ArrowRight: Icon;
    export const ExternalLink: Icon;
    export const Twitter: Icon;
    export const MessageSquare: Icon;
    export const Share2: Icon;
    export const Heart: Icon;
    export const Info: Icon;
    export const HelpCircle: Icon;
    export const Plus: Icon;
    export const Image: Icon;
    export const Play: Icon;
    export const MoreHorizontal: Icon;
    export const BarChart: Icon;
    export const MapPin: Icon;
    export const Calendar: Icon;
    export const DollarSign: Icon;
    export const CreditCard: Icon;
    export const Clock: Icon;
    export const Check: Icon;
    export const Trash: Icon;
    export const Edit: Icon;
    export const Shield: Icon;
    export const Layout: Icon;
    export const ChevronRight: Icon;
    export const Menu: Icon;
    export const X: Icon;
    export const ArrowRightCircle: Icon;
    export const Github: Icon;
    export const Linkedin: Icon;
    export const [key: string]: any;
}

declare module 'firebase/app' {
    export function initializeApp(config: any): any;
    export function getApps(): any[];
}

declare module 'firebase/auth' {
    export function getAuth(app?: any): any;
    export function onAuthStateChanged(auth: any, nextOrObserver: any): any;
    export function signInWithPopup(auth: any, provider: any): Promise<any>;
    export function signOut(auth: any): Promise<void>;
    export function multiFactor(user: any): any;
    export function totpMultiFactorGenerator(auth: any): any;
    export class TotpMultiFactorAssertion { }
    export class User { }
    export class GoogleAuthProvider {
        constructor();
    }
    export function updateProfile(user: any, profile: any): Promise<void>;
    export function updatePassword(user: any, password: string): Promise<void>;
    export function createUserWithEmailAndPassword(auth: any, email: string, password: string): Promise<any>;
    export function sendPasswordResetEmail(auth: any, email: string): Promise<void>;
    export function signInWithEmailAndPassword(auth: any, email: string, password: string): Promise<any>;
}

declare module 'firebase/firestore' {
    export function getFirestore(app?: any): any;
    export function collection(db: any, path: string): any;
    export function query(collection: any, ...constraints: any[]): any;
    export function where(fieldPath: string, opStr: string, value: any): any;
    export function orderBy(fieldPath: string, directionStr?: string): any;
    export function limit(limit: number): any;
    export function onSnapshot(query: any, onNext: (snapshot: any) => void): () => void;
    export function doc(db: any, collection: string, id: string): any;
    export function updateDoc(reference: any, data: any): Promise<void>;
    export function deleteDoc(reference: any): Promise<void>;
    export function getDoc(reference: any): Promise<any>;
    export function getDocs(query: any): Promise<any>;
    export function setDoc(reference: any, data: any): Promise<void>;
    export function onSnapshot(query: any, callback: any): any;
}
