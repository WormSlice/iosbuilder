import {
    multiFactor,
    totpMultiFactorGenerator,
    TotpMultiFactorAssertion,
    User
} from "firebase/auth";
import { auth } from "./firebase";

/**
 * Generates a TOTP secret for the given user.
 * @param user The currently authenticated Firebase user.
 * @returns An object containing the totpSecret and the QR code URL.
 */
export const generateTotpSecret = async (user: User) => {
    const multiFactorUser = multiFactor(user);
    const totpGenerator = totpMultiFactorGenerator(auth);

    const totpSecret = await totpGenerator.generateSecret(multiFactorUser);

    // You can customize the issuer name (e.g., 'CONNECT')
    const qrCodeUrl = totpSecret.generateQrCodeUrl(user.email || 'user@example.com', 'CONNECT');

    return { totpSecret, qrCodeUrl };
};

/**
 * Enrolls the user in TOTP MFA after verifying the code.
 * @param user The currently authenticated Firebase user.
 * @param totpSecret The secret generated in the previous step.
 * @param verificationCode The 6-digit code from Google Authenticator.
 * @param displayName A friendly name for this MFA factor.
 */
export const enrollMfa = async (
    user: User,
    totpSecret: any,
    verificationCode: string,
    displayName: string = 'Google Authenticator'
) => {
    const assertion = TotpMultiFactorAssertion.fromTwoFactorCode(totpSecret, verificationCode);
    await multiFactor(user).enroll(assertion, { displayName });
};

/**
 * Unenrolls all MFA factors for the user.
 * (Note: You might want to filter or allow selecting which one to remove)
 */
export const unenrollMfa = async (user: User) => {
    const multiFactorUser = multiFactor(user);
    const enrolledFactors = multiFactorUser.enrolledFactors;

    for (const factor of enrolledFactors) {
        await multiFactorUser.unenroll(factor);
    }
};
