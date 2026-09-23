import React, { useState, useEffect, useRef, FormEvent } from 'react';
import { useNavigate, Link } from 'react-router-dom';
import {
    Mail,
    Lock,
    ArrowRight,
    Eye,
    EyeOff,
    Shield,
    Smartphone,
    LogOut,
    Check
} from 'lucide-react';
import { motion, AnimatePresence } from 'framer-motion';
import { auth, db, ALLOWED_EMAILS } from '../services/firebase';
import {
    signInWithEmailAndPassword,
    signOut,
    RecaptchaVerifier,
    signInWithPhoneNumber,
    ConfirmationResult,
    User
} from 'firebase/auth';
import { doc, getDoc, setDoc, deleteDoc, serverTimestamp, Timestamp } from 'firebase/firestore';

declare global {
    interface Window {
        recaptchaVerifier?: RecaptchaVerifier;
    }
}

export const Login: React.FC = () => {
    const navigate = useNavigate();

    // Primary Credentials State
    const [email, setEmail] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [loading, setLoading] = useState(false);
    const [error, setError] = useState<string | null>(null);

    // 2FA State
    const [step, setStep] = useState<'login' | '2fa'>('login');
    const [twoFactorUser, setTwoFactorUser] = useState<User | null>(null);
    const [twoFactorMethod, setTwoFactorMethod] = useState<'sms' | 'email'>('sms');
    const [userPhone, setUserPhone] = useState<string | null>(null);
    const [userEmail, setUserEmail] = useState<string | null>(null);
    const [codeDigits, setCodeDigits] = useState<string[]>(['', '', '', '', '', '']);
    const [confirmationResult, setConfirmationResult] = useState<ConfirmationResult | null>(null);
    const [countdown, setCountdown] = useState<number>(60);
    const [isSendingCode, setIsSendingCode] = useState<boolean>(false);
    const [isVerifyingCode, setIsVerifyingCode] = useState<boolean>(false);

    const digitInputRefs = useRef<(HTMLInputElement | null)[]>([]);

    // Countdown Timer for 2FA Resend
    useEffect(() => {
        let interval: any = null;
        if (step === '2fa' && countdown > 0) {
            interval = setInterval(() => {
                setCountdown((prev) => prev - 1);
            }, 1000);
        }
        return () => {
            if (interval) clearInterval(interval);
        };
    }, [step, countdown]);

    // Destination router
    const redirectAfterAuth = (user: User) => {
        if (user.email && ALLOWED_EMAILS.includes(user.email)) {
            navigate('/admin/dashboard');
        } else {
            navigate('/');
        }
    };

    // Post-Login 2FA Check
    const handlePostLogin = async (user: User) => {
        try {
            const userDoc = await getDoc(doc(db, 'users', user.uid));
            if (userDoc.exists()) {
                const data = userDoc.data();
                if (data?.twoFactorEnabled) {
                    const method = (data?.twoFactorMethod as 'sms' | 'email') || 'sms';
                    const phone = data?.phone || user.phoneNumber || null;
                    const mail = data?.email || user.email || null;

                    setTwoFactorUser(user);
                    setUserPhone(phone);
                    setUserEmail(mail);

                    // If user requested SMS but has no phone registered, fallback to email
                    const initialMethod = method === 'sms' && !phone ? 'email' : method;
                    setTwoFactorMethod(initialMethod);
                    setStep('2fa');
                    setError(null);

                    // Send the 2FA code immediately
                    await triggerSend2FACode(user, initialMethod, phone, mail);
                    return;
                }
            }
            // 2FA not enabled
            redirectAfterAuth(user);
        } catch (err: any) {
            console.error('Error validating 2FA:', err);
            // Default to granting access if firestore fails
            redirectAfterAuth(user);
        }
    };

    // Send 2FA Code (SMS or Email)
    const triggerSend2FACode = async (
        user: User,
        method: 'sms' | 'email',
        phone: string | null,
        mail: string | null
    ) => {
        setIsSendingCode(true);
        setError(null);
        setCountdown(60);

        try {
            if (method === 'sms') {
                if (!phone) {
                    throw new Error('No tienes un teléfono registrado. Por favor verifica por correo.');
                }

                // Initialize invisible reCAPTCHA for Web SMS
                if (!window.recaptchaVerifier) {
                    window.recaptchaVerifier = new RecaptchaVerifier(auth, 'recaptcha-container', {
                        size: 'invisible'
                    });
                }

                const confirmation = await signInWithPhoneNumber(
                    auth,
                    phone,
                    window.recaptchaVerifier
                );
                setConfirmationResult(confirmation);
            } else {
                // Email method via Cloudflare Worker + temp_2fa_codes
                const targetEmail = mail || user.email;
                if (!targetEmail) throw new Error('No hay un correo asociado a tu cuenta.');

                const code = Math.floor(100000 + Math.random() * 900000).toString();

                await setDoc(doc(db, 'temp_2fa_codes', user.uid), {
                    code,
                    method: 'email',
                    createdAt: serverTimestamp(),
                    expiresAt: new Date(Date.now() + 5 * 60 * 1000)
                });

                await fetch('https://connect-email-receiver.irenzulsierra.workers.dev', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        from: 'contacto@connectapp.com.co',
                        to: targetEmail,
                        subject: 'Código de Verificación 2FA - CONNECT',
                        text: `Tu código de verificación es: ${code}\nEste código expira en 5 minutos.`,
                        html: `<div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e0e0e0; border-radius: 10px; text-align: center; background-color: #f9f9f9;"><h2 style="color: #0094FF; margin-bottom: 20px; font-weight: bold; letter-spacing: 2px;">CONNECT</h2><p style="font-size: 16px; color: #333;">Hola,</p><p style="font-size: 16px; color: #333;">Tu código de verificación seguro de dos pasos es:</p><div style="font-size: 32px; font-weight: bold; color: #fff; background-color: #0094FF; padding: 15px 30px; margin: 20px auto; width: fit-content; border-radius: 8px; letter-spacing: 4px;">${code}</div><p style="font-size: 14px; color: #777;">Este código expira en 5 minutos. No compartas esto con nadie.</p></div>`
                    })
                });
            }

            // Focus on first box
            setTimeout(() => {
                digitInputRefs.current[0]?.focus();
            }, 100);
        } catch (err: any) {
            console.error('Error dispatching 2FA code:', err);
            if (method === 'sms') {
                setError('No se pudo enviar el SMS. Intenta con verificación por correo.');
            } else {
                setError('Error al enviar el correo de verificación.');
            }
        } finally {
            setIsSendingCode(false);
        }
    };

    // Switch between SMS and Email on the 2FA view
    const handleSwitchMethod = async () => {
        if (!twoFactorUser) return;
        const newMethod = twoFactorMethod === 'sms' ? 'email' : 'sms';
        if (newMethod === 'sms' && !userPhone) {
            setError('No tienes un número de teléfono registrado en tu perfil.');
            return;
        }
        setTwoFactorMethod(newMethod);
        setCodeDigits(['', '', '', '', '', '']);
        await triggerSend2FACode(twoFactorUser, newMethod, userPhone, userEmail);
    };

    // Handle Digit Input Box Typing
    const handleDigitChange = (index: number, val: string) => {
        const cleaned = val.replace(/\D/g, '');
        const newDigits = [...codeDigits];

        if (cleaned.length > 1) {
            // User pasted multiple characters (e.g. 123456)
            const pasted = cleaned.slice(0, 6).split('');
            for (let i = 0; i < 6; i++) {
                newDigits[i] = pasted[i] || '';
            }
            setCodeDigits(newDigits);
            const nextIdx = Math.min(pasted.length, 5);
            digitInputRefs.current[nextIdx]?.focus();

            if (newDigits.every((d) => d.length === 1)) {
                verifyCode(newDigits.join(''));
            }
            return;
        }

        newDigits[index] = cleaned;
        setCodeDigits(newDigits);

        if (cleaned && index < 5) {
            digitInputRefs.current[index + 1]?.focus();
        }

        if (newDigits.every((d) => d.length === 1)) {
            verifyCode(newDigits.join(''));
        }
    };

    const handleDigitKeyDown = (index: number, e: React.KeyboardEvent<HTMLInputElement>) => {
        if (e.key === 'Backspace' && !codeDigits[index] && index > 0) {
            digitInputRefs.current[index - 1]?.focus();
        }
    };

    // Verify 2FA Code
    const verifyCode = async (fullCode?: string) => {
        const code = fullCode || codeDigits.join('');
        if (code.length < 6 || !twoFactorUser) return;

        setIsVerifyingCode(true);
        setError(null);

        try {
            if (twoFactorMethod === 'sms') {
                if (!confirmationResult) {
                    throw new Error('Solicita un nuevo código SMS para continuar.');
                }
                await confirmationResult.confirm(code);
                redirectAfterAuth(twoFactorUser);
            } else {
                // Email verification against temp_2fa_codes
                const codeDoc = await getDoc(doc(db, 'temp_2fa_codes', twoFactorUser.uid));
                if (!codeDoc.exists()) {
                    throw new Error('El código ha expirado o no es válido.');
                }
                const data = codeDoc.data();
                const storedCode = data?.code;
                const expiresAt = (data?.expiresAt as Timestamp)?.toDate();

                if (new Date() > expiresAt) {
                    await deleteDoc(codeDoc.ref);
                    throw new Error('El código ha expirado. Solicita uno nuevo.');
                }

                if (storedCode === code) {
                    await deleteDoc(codeDoc.ref);
                    redirectAfterAuth(twoFactorUser);
                } else {
                    throw new Error('Código incorrecto. Verifica los 6 dígitos.');
                }
            }
        } catch (err: any) {
            console.error('Verification failed:', err);
            setError(err.message || 'Código de seguridad incorrecto.');
            setCodeDigits(['', '', '', '', '', '']);
            digitInputRefs.current[0]?.focus();
        } finally {
            setIsVerifyingCode(false);
        }
    };

    // Cancel 2FA and Return to Login
    const handleCancel2FA = async () => {
        try {
            await signOut(auth);
        } catch (_) {}
        setStep('login');
        setTwoFactorUser(null);
        setCodeDigits(['', '', '', '', '', '']);
        setError(null);
    };

    // Primary Email/Password Login Submission
    const handleLogin = async (e: FormEvent<HTMLFormElement>) => {
        e.preventDefault();
        setLoading(true);
        setError(null);
        try {
            const userCredential = await signInWithEmailAndPassword(auth, email.trim(), password);
            await handlePostLogin(userCredential.user);
        } catch (err: any) {
            setError('Correo electrónico o contraseña incorrectos.');
        } finally {
            setLoading(false);
        }
    };

    // Social Logins
    const handleGoogleLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const { googleProvider, signInWithPopup } = await import('../services/firebase');
            const result = await signInWithPopup(auth, googleProvider);
            await handlePostLogin(result.user);
        } catch (err: any) {
            setError('No se pudo completar el inicio de sesión con Google.');
        } finally {
            setLoading(false);
        }
    };

    const handleAppleLogin = async () => {
        setLoading(true);
        setError(null);
        try {
            const { appleProvider, signInWithPopup } = await import('../services/firebase');
            const result = await signInWithPopup(auth, appleProvider);
            await handlePostLogin(result.user);
        } catch (err: any) {
            console.error('Apple Login Error:', err);
            if (err?.code === 'auth/popup-closed-by-user') {
                setError('Ventana de inicio de sesión cerrada.');
            } else {
                setError('Error con Apple Sign In. Si persiste, inicia sesión con Google o correo.');
            }
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen flex items-center justify-center bg-[#07080A] text-white p-4 sm:p-6 relative overflow-hidden">
            {/* Invisible reCAPTCHA container for Phone Auth on Web */}
            <div id="recaptcha-container"></div>

            {/* Ambient Background Mesh */}
            <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[700px] h-[500px] bg-gradient-to-b from-[#0094FF]/[0.08] via-transparent to-transparent blur-3xl pointer-events-none -z-10" />

            <motion.div
                initial={{ opacity: 0, y: 20, scale: 0.98 }}
                animate={{ opacity: 1, y: 0, scale: 1 }}
                transition={{ duration: 0.5, ease: [0.16, 1, 0.3, 1] }}
                className="w-full max-w-md bg-[#0F1117]/80 backdrop-blur-2xl border border-white/[0.08] rounded-3xl p-7 sm:p-10 shadow-2xl relative z-10"
            >
                {/* Header */}
                <div className="text-center space-y-2 mb-8">
                    <Link to="/" className="inline-flex justify-center group mb-2">
                        <img
                            src="/logo.png"
                            alt="CONNECT"
                            className="h-10 w-10 object-contain brightness-125 transition-transform duration-300 group-hover:scale-105"
                        />
                    </Link>
                    <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight font-archivo text-white">
                        {step === 'login' ? 'Iniciar Sesión' : 'Verificación en Dos Pasos'}
                    </h1>
                    <p className="text-xs sm:text-sm text-zinc-400 font-normal">
                        {step === 'login'
                            ? 'Ingresa a tu cuenta de CONNECT'
                            : twoFactorMethod === 'sms'
                            ? `Ingresa el código enviado por SMS a tu teléfono ${
                                  userPhone && userPhone.length > 4
                                      ? `•••• ${userPhone.slice(-4)}`
                                      : 'registrado'
                              }`
                            : `Ingresa el código enviado a tu correo ${
                                  userEmail ? userEmail.replace(/(.{2})(.*)(?=@)/, '$1••••') : 'registrado'
                              }`}
                    </p>
                </div>

                {/* STEP 1: LOGIN FORM */}
                {step === 'login' && (
                    <>
                        {/* Social Login Buttons */}
                        <div className="grid grid-cols-2 gap-3 mb-6">
                            <button
                                type="button"
                                onClick={handleGoogleLogin}
                                disabled={loading}
                                className="bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/[0.1] rounded-2xl py-3 px-3 text-xs font-semibold transition-all duration-200 flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-50 cursor-pointer"
                            >
                                <svg viewBox="0 0 24 24" className="w-4 h-4 shrink-0" xmlns="http://www.w3.org/2000/svg">
                                    <path d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z" fill="#4285F4" />
                                    <path d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z" fill="#34A853" />
                                    <path d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.07H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.93l3.66-2.84z" fill="#FBBC05" />
                                    <path d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.07l3.66 2.84c.87-2.6 3.3-4.53 6.16-4.53z" fill="#EA4335" />
                                </svg>
                                <span>Google</span>
                            </button>

                            <button
                                type="button"
                                onClick={handleAppleLogin}
                                disabled={loading}
                                className="bg-white/[0.04] hover:bg-white/[0.08] text-white border border-white/[0.1] rounded-2xl py-3 px-3 text-xs font-semibold transition-all duration-200 flex items-center justify-center gap-2 active:scale-[0.98] disabled:opacity-50 cursor-pointer"
                            >
                                <svg viewBox="0 0 24 24" className="w-4 h-4 fill-white shrink-0" xmlns="http://www.w3.org/2000/svg">
                                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.1 2.48-1.34.03-1.77-.79-3.29-.79-1.53 0-2.01.77-3.27.82-1.31.05-2.31-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91 1.65.07 2.49.52 3.01.99.11.11.23.23.33.36-1.3.77-2.13 2.1-2.09 3.63.04 1.88 1.58 3.32 3.44 3.42-.04.42-.1.85-.2 1.25zM12.91 5.99c.35-1.5 1.77-2.61 3.35-2.6.14 1.58-1.28 3.16-3.35 3.1-.14-1.58-.2-2.5.3-3.1z" />
                                </svg>
                                <span>Apple</span>
                            </button>
                        </div>

                        {/* Divider */}
                        <div className="flex items-center gap-3 my-6">
                            <div className="flex-1 h-px bg-white/[0.08]" />
                            <span className="text-[11px] font-medium text-zinc-500 uppercase tracking-wider">o con correo</span>
                            <div className="flex-1 h-px bg-white/[0.08]" />
                        </div>

                        {/* Email Form */}
                        <form onSubmit={handleLogin} className="space-y-4">
                            <div className="space-y-1.5">
                                <label className="text-xs font-semibold text-zinc-300">Correo Electrónico</label>
                                <div className="relative">
                                    <Mail className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                                    <input
                                        type="email"
                                        value={email}
                                        onChange={(e) => setEmail(e.target.value)}
                                        required
                                        className="w-full bg-white/[0.03] border border-white/[0.1] hover:border-white/20 focus:border-[#0094FF] focus:bg-white/[0.05] rounded-xl pl-10 pr-4 py-3 text-xs sm:text-sm text-white placeholder:text-zinc-500 outline-none transition-all"
                                        placeholder="tu@correo.com"
                                    />
                                </div>
                            </div>

                            <div className="space-y-1.5">
                                <div className="flex justify-between items-center">
                                    <label className="text-xs font-semibold text-zinc-300">Contraseña</label>
                                    <Link to="/reset-password" className="text-xs text-[#0094FF] hover:underline font-medium">
                                        ¿Olvidaste tu contraseña?
                                    </Link>
                                </div>
                                <div className="relative">
                                    <Lock className="absolute left-3.5 top-1/2 -translate-y-1/2 text-zinc-500" size={16} />
                                    <input
                                        type={showPassword ? 'text' : 'password'}
                                        value={password}
                                        onChange={(e) => setPassword(e.target.value)}
                                        required
                                        className="w-full bg-white/[0.03] border border-white/[0.1] hover:border-white/20 focus:border-[#0094FF] focus:bg-white/[0.05] rounded-xl pl-10 pr-10 py-3 text-xs sm:text-sm text-white placeholder:text-zinc-500 outline-none transition-all"
                                        placeholder="••••••••"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowPassword(!showPassword)}
                                        className="absolute right-3.5 top-1/2 -translate-y-1/2 text-zinc-500 hover:text-zinc-300 transition-colors cursor-pointer"
                                    >
                                        {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                                    </button>
                                </div>
                            </div>

                            <AnimatePresence>
                                {error && (
                                    <motion.div
                                        initial={{ opacity: 0, height: 0 }}
                                        animate={{ opacity: 1, height: 'auto' }}
                                        exit={{ opacity: 0, height: 0 }}
                                        className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium text-center"
                                    >
                                        {error}
                                    </motion.div>
                                )}
                            </AnimatePresence>

                            <button
                                type="submit"
                                disabled={loading}
                                className="w-full bg-[#0094FF] hover:bg-[#0080DF] text-white text-xs sm:text-sm font-bold py-3 px-6 rounded-xl transition-all duration-200 active:scale-[0.98] shadow-md shadow-[#0094FF]/20 flex items-center justify-center gap-2 disabled:opacity-50 cursor-pointer pt-3"
                            >
                                {loading ? (
                                    <div className="animate-spin h-4 w-4 border-2 border-white/20 border-t-white rounded-full" />
                                ) : (
                                    <>
                                        <span>Iniciar Sesión</span>
                                        <ArrowRight size={15} />
                                    </>
                                )}
                            </button>
                        </form>

                        {/* Bottom Link */}
                        <div className="text-center pt-6 mt-6 border-t border-white/[0.08]">
                            <p className="text-xs text-zinc-400">
                                ¿No tienes una cuenta?{' '}
                                <Link to="/signup" className="text-[#0094FF] font-bold hover:underline">
                                    Regístrate
                                </Link>
                            </p>
                        </div>
                    </>
                )}

                {/* STEP 2: 2FA VERIFICATION */}
                {step === '2fa' && (
                    <div className="space-y-6">
                        {/* Method Indicator */}
                        <div className="flex items-center justify-center gap-2 p-2 rounded-xl bg-white/[0.04] border border-white/[0.08] text-xs text-zinc-300">
                            {twoFactorMethod === 'sms' ? (
                                <>
                                    <Smartphone size={15} className="text-[#0094FF]" />
                                    <span>Código enviado vía SMS</span>
                                </>
                            ) : (
                                <>
                                    <Mail size={15} className="text-[#0094FF]" />
                                    <span>Código enviado vía Correo</span>
                                </>
                            )}
                        </div>

                        {/* 6 Digit Inputs */}
                        <div className="flex justify-between gap-2">
                            {codeDigits.map((digit, idx) => (
                                <input
                                    key={idx}
                                    ref={(el) => (digitInputRefs.current[idx] = el)}
                                    type="text"
                                    inputMode="numeric"
                                    maxLength={1}
                                    value={digit}
                                    onChange={(e) => handleDigitChange(idx, e.target.value)}
                                    onKeyDown={(e) => handleDigitKeyDown(idx, e)}
                                    className="w-12 h-14 bg-white/[0.04] border border-white/[0.1] focus:border-[#0094FF] focus:bg-white/[0.08] rounded-xl text-center text-xl font-bold text-white outline-none transition-all"
                                />
                            ))}
                        </div>

                        <AnimatePresence>
                            {error && (
                                <motion.div
                                    initial={{ opacity: 0, height: 0 }}
                                    animate={{ opacity: 1, height: 'auto' }}
                                    exit={{ opacity: 0, height: 0 }}
                                    className="p-3 rounded-xl bg-red-500/10 border border-red-500/20 text-red-400 text-xs font-medium text-center"
                                >
                                    {error}
                                </motion.div>
                            )}
                        </AnimatePresence>

                        {/* Action Verify Button */}
                        <button
                            type="button"
                            onClick={() => verifyCode()}
                            disabled={isVerifyingCode || codeDigits.some((d) => d === '')}
                            className="w-full bg-[#0094FF] hover:bg-[#0080DF] text-white text-xs sm:text-sm font-bold py-3 px-6 rounded-xl transition-all duration-200 active:scale-[0.98] shadow-md shadow-[#0094FF]/20 flex items-center justify-center gap-2 disabled:opacity-40 cursor-pointer"
                        >
                            {isVerifyingCode ? (
                                <div className="animate-spin h-4 w-4 border-2 border-white/20 border-t-white rounded-full" />
                            ) : (
                                <>
                                    <Check size={16} />
                                    <span>Verificar y Continuar</span>
                                </>
                            )}
                        </button>

                        {/* Resend & Switch Controls */}
                        <div className="flex flex-col items-center gap-2 pt-2">
                            <button
                                type="button"
                                onClick={() =>
                                    twoFactorUser &&
                                    triggerSend2FACode(twoFactorUser, twoFactorMethod, userPhone, userEmail)
                                }
                                disabled={countdown > 0 || isSendingCode}
                                className="text-xs font-semibold text-[#0094FF] hover:text-[#38b6ff] disabled:text-zinc-600 transition-colors cursor-pointer"
                            >
                                {isSendingCode
                                    ? 'Enviando código...'
                                    : countdown > 0
                                    ? `Reenviar código en ${countdown}s`
                                    : '¿No recibiste el código? Reenviar'}
                            </button>

                            <button
                                type="button"
                                onClick={handleSwitchMethod}
                                disabled={isSendingCode}
                                className="text-xs text-zinc-400 hover:text-white transition-colors underline cursor-pointer mt-1"
                            >
                                {twoFactorMethod === 'sms'
                                    ? 'Probar con Correo Electrónico en su lugar'
                                    : 'Probar con Mensaje de Texto (SMS) en su lugar'}
                            </button>
                        </div>

                        {/* Cancel Button */}
                        <div className="pt-4 border-t border-white/[0.08] text-center">
                            <button
                                type="button"
                                onClick={handleCancel2FA}
                                className="text-xs text-zinc-500 hover:text-red-400 transition-colors inline-flex items-center gap-1.5 cursor-pointer"
                            >
                                <LogOut size={13} />
                                <span>Cancelar y volver al inicio de sesión</span>
                            </button>
                        </div>
                    </div>
                )}
            </motion.div>
        </div>
    );
};
