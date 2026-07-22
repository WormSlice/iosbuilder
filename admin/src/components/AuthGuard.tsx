import React, { useEffect, useState } from 'react';
import { Navigate } from 'react-router-dom';
import { onAuthStateChanged, User } from 'firebase/auth';
import { auth, ALLOWED_EMAILS } from '../services/firebase';

interface AuthGuardProps {
    children: React.ReactNode;
    adminOnly?: boolean;
}

export const AuthGuard: React.FC<AuthGuardProps> = ({ children, adminOnly = true }) => {
    const [user, setUser] = useState<User | null>(null);
    const [loading, setLoading] = useState(true);

    useEffect(() => {
        const unsubscribe = onAuthStateChanged(auth, (currentUser: User | null) => {
            setUser(currentUser);
            setLoading(false);
        });

        return () => unsubscribe();
    }, []);

    if (loading) {
        return (
            <div className="min-h-screen flex items-center justify-center bg-white">
                <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary"></div>
            </div>
        );
    }

    if (!user) {
        return <Navigate to="/login" replace />;
    }

    // Check if the user is authorized for admin panel if adminOnly is true
    if (adminOnly && user.email && !ALLOWED_EMAILS.includes(user.email)) {
        return <Navigate to="/" replace />;
    }

    return <>{children}</>;
};
