import React from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { AuthGuard } from './components/AuthGuard';
import { Layout } from './components/Layout';
import { PublicLayout } from './components/PublicLayout';

// Public Pages
import { Home } from './pages/Home';
import { About } from './pages/About';
import { HowItWorks } from './pages/HowItWorks';
import { FAQ } from './pages/FAQ';
import { Report } from './pages/Report';
import { Support } from './pages/Support';
import { PrivacyPolicy } from './pages/PrivacyPolicy';

// Auth Pages
import { Login } from './pages/Login';
import { Signup } from './pages/Signup';
import { ResetPassword } from './pages/ResetPassword';

// Admin Pages
import { Publications } from './pages/Publications';
import { Dashboard } from './pages/Dashboard';
import { Users } from './pages/Users';
import { Verifications } from './pages/Verifications';
import { Boosts } from './pages/Boosts';
import { Ads } from './pages/Ads';
import { Reports } from './pages/Reports';
import { Notifications } from './pages/Notifications';
import { Tools } from './pages/Tools';
import { Mail } from './pages/Mail';
import { Settings } from './pages/Settings';
import { SupportRequests } from './pages/SupportRequests';
import { ErrorBoundary } from './components/ErrorBoundary';

const App: React.FC = () => {
    return (
        <Router>
            <Routes>
                {/* Public Website Routes (Root) */}
                <Route element={<PublicLayout />}>
                    <Route path="/" element={<Home />} />
                    <Route path="/about" element={<About />} />
                    <Route path="/how-it-works" element={<HowItWorks />} />
                    <Route path="/faq" element={<FAQ />} />
                    <Route path="/report" element={<Report />} />
                    <Route path="/support" element={<Support />} />
                    <Route path="/privacy-policy" element={<PrivacyPolicy />} />
                    <Route path="/settings" element={<AuthGuard adminOnly={false}><Settings /></AuthGuard>} />
                </Route>

                {/* Auth Routes */}
                <Route path="/login" element={<Login />} />
                <Route path="/signup" element={<Signup />} />
                <Route path="/reset-password" element={<ResetPassword />} />

                {/* Admin Routes (Prefixed with /admin) */}
                <Route path="/admin" element={<AuthGuard><ErrorBoundary><Layout /></ErrorBoundary></AuthGuard>}>
                    <Route index element={<Navigate to="dashboard" replace />} />
                    <Route path="dashboard" element={<Dashboard />} />
                    <Route path="users" element={<Users />} />
                    <Route path="verifications" element={<Verifications />} />
                    <Route path="boosts" element={<Boosts />} />
                    <Route path="ads" element={<Ads />} />
                    <Route path="publications" element={<Publications />} />
                    <Route path="reports" element={<Reports />} />
                    <Route path="notifications" element={<Notifications />} />
                    <Route path="mail" element={<Mail />} />
                    <Route path="support" element={<SupportRequests />} />
                    <Route path="tools" element={<Tools />} />
                </Route>

                {/* Catch All */}
                <Route path="*" element={<Navigate to="/" replace />} />
            </Routes>
        </Router>
    );
};

export default App;
