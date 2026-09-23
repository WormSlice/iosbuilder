import React from 'react';
import { Outlet, useLocation } from 'react-router-dom';
import { Navbar } from './Navbar';
import { Footer } from './Footer';
import { motion, AnimatePresence } from 'framer-motion';

export const PublicLayout: React.FC = () => {
    const location = useLocation();

    return (
        <div className="flex flex-col min-h-screen bg-[#07080A] text-white selection:bg-[#0094FF] selection:text-white">
            <Navbar />
            <main className="flex-1 relative overflow-x-clip pt-20">
                <AnimatePresence mode="wait">
                    <motion.div
                        key={location.pathname}
                        initial={{ opacity: 0, translateY: 8 }}
                        animate={{ opacity: 1, translateY: 0 }}
                        exit={{ opacity: 0, translateY: -8 }}
                        transition={{
                            duration: 0.35,
                            ease: [0.16, 1, 0.3, 1]
                        }}
                        className="min-h-full"
                    >
                        <Outlet />
                    </motion.div>
                </AnimatePresence>
            </main>
            <Footer />
        </div>
    );
};
