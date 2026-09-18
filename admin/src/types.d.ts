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

declare module 'lucide-react';

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
