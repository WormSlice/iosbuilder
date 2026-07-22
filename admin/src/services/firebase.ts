import { initializeApp } from "firebase/app";
import {
    getAuth,
    GoogleAuthProvider,
    signInWithEmailAndPassword,
    signInWithPopup,
    createUserWithEmailAndPassword,
    sendPasswordResetEmail,
    updateProfile,
    updatePassword,
    signOut,
    onAuthStateChanged
} from "firebase/auth";
import { getFirestore } from "firebase/firestore";
import { getStorage } from "firebase/storage";

const firebaseConfig = {
    apiKey: "AIzaSyDLb-a9BehwwbgUFKgY2oUQlwgYrbQFKZU",
    authDomain: "connectapp.com.co",
    projectId: "connect2025-37b7c",
    storageBucket: "connect2025-37b7c.firebasestorage.app",
    messagingSenderId: "749754037761",
    appId: "1:749754037761:web:unknown"
};

const app = initializeApp(firebaseConfig);
export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export const googleProvider = new GoogleAuthProvider();

export {
    signInWithEmailAndPassword,
    signInWithPopup,
    createUserWithEmailAndPassword,
    sendPasswordResetEmail,
    updateProfile,
    updatePassword,
    signOut,
    onAuthStateChanged
};

export const ALLOWED_EMAILS = [
    'irenzulsierra@gmail.com',
    'soporte@connectapp.com.co',
    'gvalentino8@hotmail.com',
    'givacos@gmail.com'
];
