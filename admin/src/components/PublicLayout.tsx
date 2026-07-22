import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Navbar } from './Navbar';
import { Footer } from './Footer';
import { motion, AnimatePresence } from 'framer-motion';

export const PublicLayout: React.FC = () => {
    const location = useLocation();

    return (
        <div className="flex flex-col min-h-screen bg-[#0a0a0a] text-white">
            <Navbar />
            <main className="flex-1 relative overflow-hidden">
                <AnimatePresence mode="wait">
                    <motion.div
                        key={location.pathname}
                        initial={{ opacity: 0, scale: 0.98, translateY: 10 }}
                        animate={{ opacity: 1, scale: 1, translateY: 0 }}
                        exit={{ opacity: 0, scale: 1.02, translateY: -10 }}
                        transition={{
                            duration: 0.4,
                            ease: [0.22, 1, 0.36, 1]
                        }}
                        className="min-h-full"
                    >
                        {/* Transition overlay effect indicated by user "emerging from button" */}
                        {/* We use a simple but premium fade + scale for now to ensure quality */}
                        <Outlet />
                    </motion.div>
                </AnimatePresence>
            </main>
            <Footer />
        </div>
    );
};
