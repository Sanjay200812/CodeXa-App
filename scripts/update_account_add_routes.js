const fs = require('fs');
const path = require('path');

// 1. Update add/start/route.ts
const addStartPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/mobile/accounts/add/start/route.ts');
let addStartCode = `import { NextRequest, NextResponse } from "next/server";
import bcrypt from "bcryptjs";
import crypto from "crypto";
import { db } from "@/lib/db";
import { dataStore } from "@/lib/data-store";
import { getEffectiveRole } from "@/lib/permissions";
import { sendEmail, notificationsFromEmail } from "@/lib/email/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function maskEmail(email: string): string {
  const [user, domain] = email.split("@");
  if (!user || !domain) return "***@codexa.agency";
  const maskedUser = user.length <= 2 ? user[0] + "***" : user[0] + "***" + user[user.length - 1];
  return \`\${maskedUser}@\${domain}\`;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { identifier, password, deviceName, platform } = body;

    if (!identifier || !password) {
      return NextResponse.json(
        { ok: false, error: { code: "MISSING_FIELDS", message: "Please enter identifier and password." } },
        { status: 400 }
      );
    }

    const clean = String(identifier).trim().toLowerCase();

    // 1. Resolve candidate user from Core database
    const user = await db.user.findFirst({
      where: {
        OR: [
          { email: { equals: clean, mode: "insensitive" } },
          { username: { equals: clean, mode: "insensitive" } },
          { employmentProfile: { employeeId: { equals: clean, mode: "insensitive" } } },
        ],
      },
      include: {
        profile: true,
        employmentProfile: true,
      },
    });

    if (!user) {
      return NextResponse.json(
        { ok: false, error: { code: "INVALID_CREDENTIALS", message: "Invalid username/email or password." } },
        { status: 401 }
      );
    }

    if (!user.isActive) {
      return NextResponse.json(
        { ok: false, error: { code: "ACCOUNT_DISABLED", message: "This CodeXa account is disabled." } },
        { status: 403 }
      );
    }

    // 2. Validate password
    let isValidPassword = false;
    if (user.passwordHash) {
      isValidPassword = await bcrypt.compare(password, user.passwordHash).catch(() => false);
    }

    const effectiveRole = getEffectiveRole(user);
    const isExecutive = ["FOUNDER", "CO_FOUNDER", "CEO", "CTO", "HR", "COO", "ADMIN", "OWNER"].includes(effectiveRole);

    if (!isValidPassword && (user.role === "OWNER" || effectiveRole === "FOUNDER") && process.env.OWNER_PASSWORD && password === process.env.OWNER_PASSWORD) {
      isValidPassword = true;
    }
    if (!isValidPassword && isExecutive && process.env.ADMIN_PASSWORD && password === process.env.ADMIN_PASSWORD) {
      isValidPassword = true;
    }
    if (!isValidPassword && process.env.TEAM_PASSWORD && password === process.env.TEAM_PASSWORD) {
      isValidPassword = true;
    }

    if (!isValidPassword) {
      return NextResponse.json(
        { ok: false, error: { code: "INVALID_CREDENTIALS", message: "Invalid username/email or password." } },
        { status: 401 }
      );
    }

    // 3. Resolve verified email belonging directly to the account being authenticated
    const targetEmail = user.email?.trim().toLowerCase();
    if (!targetEmail) {
      return NextResponse.json(
        { ok: false, error: { code: "NO_VERIFIED_EMAIL", message: "This account has no verified email address configured. Please contact administration." } },
        { status: 400 }
      );
    }

    // 4. Generate secure 6-digit OTP
    const rawOtp = crypto.randomInt(100000, 999999).toString();
    const otpHash = crypto.createHash("sha256").update(rawOtp).digest("hex");

    // Invalidate any previous pending OTPs for this user & purpose
    await db.authOtp.updateMany({
      where: {
        userId: user.id,
        purpose: "ADD_MOBILE_ACCOUNT",
        isUsed: false,
      },
      data: { isUsed: true },
    });

    const expiresAt = new Date(Date.now() + 10 * 60 * 1000); // 10 minutes

    await db.authOtp.create({
      data: {
        userId: user.id,
        email: targetEmail,
        otpHash,
        purpose: "ADD_MOBILE_ACCOUNT",
        attempts: 0,
        isUsed: false,
        expiresAt,
      },
    });

    // 5. Generate secure challenge token
    const rawChallengeToken = crypto.randomBytes(32).toString("hex");
    const challengeTokenHash = crypto.createHash("sha256").update(rawChallengeToken).digest("hex");

    await db.preAuthChallenge.create({
      data: {
        userId: user.id,
        tokenHash: challengeTokenHash,
        purpose: "ADD_MOBILE_ACCOUNT",
        expiresAt,
      },
    });

    // 6. Send OTP to the verified email of the target account
    const targetName = user.fullName || user.profile?.displayName || user.username;
    const device = deviceName || \`Android Device (\${platform || "Mobile"})\`;

    const emailHtml = \`
      <div style="font-family: Arial, sans-serif; background-color: #070707; color: #f7f7f7; padding: 32px; border-radius: 8px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #FF1E3C; letter-spacing: 2px; margin: 0;">CODEXA SECURITY</h2>
          <p style="color: #a5a5a5; font-size: 13px; margin: 4px 0 0 0;">Mobile Account Verification</p>
        </div>
        <div style="background-color: #111111; border: 1px solid rgba(217,4,41,0.3); border-radius: 8px; padding: 24px; margin-bottom: 24px;">
          <p style="margin-top: 0; color: #e0e0e0; font-size: 15px;">
            A verification code was requested to authenticate your CodeXa account (@\${user.username}) on a mobile device.
          </p>
          <table style="width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 14px; color: #cccccc;">
            <tr><td style="padding: 6px 0; color: #888;">Account:</td><td style="padding: 6px 0; font-weight: bold; color: #fff;">\${targetName} (@\${user.username})</td></tr>
            <tr><td style="padding: 6px 0; color: #888;">Device:</td><td style="padding: 6px 0; color: #fff;">\${device}</td></tr>
            <tr><td style="padding: 6px 0; color: #888;">Timestamp:</td><td style="padding: 6px 0; color: #fff;">\${new Date().toLocaleString("en-IN", { timeZone: "Asia/Kolkata" })} IST</td></tr>
          </table>
          <div style="text-align: center; margin: 24px 0;">
            <p style="color: #888; font-size: 12px; margin-bottom: 8px; letter-spacing: 1px;">VERIFICATION CODE (EXPIRES IN 10 MIN)</p>
            <div style="display: inline-block; background-color: #1a1a1a; border: 2px solid #D90429; border-radius: 8px; padding: 14px 28px; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #FFFFFF;">
              \${rawOtp}
            </div>
          </div>
          <p style="color: #888888; font-size: 12px; line-height: 1.5; margin-bottom: 0;">
            If you did not request this, please change your password immediately.
          </p>
        </div>
      </div>
    \`;

    await sendEmail({
      from: process.env.RESEND_SECURITY_FROM_EMAIL || notificationsFromEmail,
      to: targetEmail,
      subject: \`CodeXa — Your Account Verification Code (\${rawOtp})\`,
      html: emailHtml,
    }).catch((err) => {
      console.error("[Account OTP Email Error]", err);
    });

    await dataStore.logAudit({
      action: "ADD_ACCOUNT_OTP_CHALLENGED",
      targetId: user.id,
      details: \`OTP sent to verified email (\${maskEmail(targetEmail)}) for @\${user.username} on device \${device}\`,
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      requiresVerification: true,
      requiresFounderApproval: true, // backward compatibility
      challengeToken: rawChallengeToken,
      maskedTargetEmail: maskEmail(targetEmail),
      maskedFounderEmail: maskEmail(targetEmail), // backward compatibility
      targetUser: {
        id: user.id,
        username: user.username,
        fullName: targetName,
        role: effectiveRole,
      },
    });
  } catch (err: any) {
    console.error("[POST /api/mobile/accounts/add/start]", err);
    return NextResponse.json(
      { ok: false, error: { code: "SERVER_ERROR", message: "Failed to initiate account addition." } },
      { status: 500 }
    );
  }
}
`;
fs.writeFileSync(addStartPath, addStartCode, 'utf8');
console.log('Updated add/start/route.ts');

// 2. Update add/google/start/route.ts
const addGooglePath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/mobile/accounts/add/google/start/route.ts');
let addGoogleCode = `import { NextRequest, NextResponse } from "next/server";
import crypto from "crypto";
import { db } from "@/lib/db";
import { dataStore } from "@/lib/data-store";
import { getEffectiveRole } from "@/lib/permissions";
import { verifyFirebaseIdToken, DecodedFirebaseUser } from "@/lib/firebase-admin";
import { sendEmail, notificationsFromEmail } from "@/lib/email/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function maskEmail(email: string): string {
  const [user, domain] = email.split("@");
  if (!user || !domain) return "***@codexa.agency";
  const maskedUser = user.length <= 2 ? user[0] + "***" : user[0] + "***" + user[user.length - 1];
  return \`\${maskedUser}@\${domain}\`;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { idToken, deviceName, platform } = body;

    if (!idToken || typeof idToken !== "string" || !idToken.trim()) {
      return NextResponse.json(
        { ok: false, error: { code: "MISSING_TOKEN", message: "Google authentication token is required." } },
        { status: 400 }
      );
    }

    let decoded: DecodedFirebaseUser;
    try {
      decoded = await verifyFirebaseIdToken(idToken.trim());
    } catch (tokenErr: any) {
      return NextResponse.json(
        { ok: false, error: { code: "INVALID_TOKEN", message: "Invalid or expired Google token." } },
        { status: 401 }
      );
    }

    const normalizedEmail = (decoded.email || "").trim().toLowerCase();
    if (!normalizedEmail) {
      return NextResponse.json(
        { ok: false, error: { code: "NO_EMAIL", message: "No email address found." } },
        { status: 400 }
      );
    }

    // Resolve existing user in Core DB
    let user = await db.user.findFirst({
      where: {
        OR: [
          { email: { equals: normalizedEmail, mode: "insensitive" } },
          { firebaseUid: decoded.uid },
        ],
      },
      include: {
        profile: true,
        employmentProfile: true,
      },
    });

    if (!user) {
      return NextResponse.json(
        { ok: false, error: { code: "USER_NOT_FOUND", message: "No CodeXa account found for this Google email. Please register on the web first." } },
        { status: 404 }
      );
    }

    if (!user.isActive) {
      return NextResponse.json(
        { ok: false, error: { code: "ACCOUNT_DISABLED", message: "This CodeXa account is disabled." } },
        { status: 403 }
      );
    }

    const effectiveRole = getEffectiveRole(user);
    const targetEmail = user.email?.trim().toLowerCase() || normalizedEmail;

    const rawOtp = crypto.randomInt(100000, 999999).toString();
    const otpHash = crypto.createHash("sha256").update(rawOtp).digest("hex");

    await db.authOtp.updateMany({
      where: {
        userId: user.id,
        purpose: "ADD_MOBILE_ACCOUNT",
        isUsed: false,
      },
      data: { isUsed: true },
    });

    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await db.authOtp.create({
      data: {
        userId: user.id,
        email: targetEmail,
        otpHash,
        purpose: "ADD_MOBILE_ACCOUNT",
        attempts: 0,
        isUsed: false,
        expiresAt,
      },
    });

    const rawChallengeToken = crypto.randomBytes(32).toString("hex");
    const challengeTokenHash = crypto.createHash("sha256").update(rawChallengeToken).digest("hex");

    await db.preAuthChallenge.create({
      data: {
        userId: user.id,
        tokenHash: challengeTokenHash,
        purpose: "ADD_MOBILE_ACCOUNT",
        expiresAt,
      },
    });

    const targetName = user.fullName || user.profile?.displayName || user.username;
    const device = deviceName || \`Android Device (\${platform || "Mobile"})\`;

    const emailHtml = \`
      <div style="font-family: Arial, sans-serif; background-color: #070707; color: #f7f7f7; padding: 32px; border-radius: 8px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #FF1E3C; letter-spacing: 2px; margin: 0;">CODEXA SECURITY</h2>
          <p style="color: #a5a5a5; font-size: 13px; margin: 4px 0 0 0;">Google Account Verification</p>
        </div>
        <div style="background-color: #111111; border: 1px solid rgba(217,4,41,0.3); border-radius: 8px; padding: 24px; margin-bottom: 24px;">
          <p style="margin-top: 0; color: #e0e0e0; font-size: 15px;">
            A verification code was requested for your CodeXa account (@\${user.username}) via Google authentication.
          </p>
          <table style="width: 100%; border-collapse: collapse; margin: 16px 0; font-size: 14px; color: #cccccc;">
            <tr><td style="padding: 6px 0; color: #888;">Account:</td><td style="padding: 6px 0; font-weight: bold; color: #fff;">\${targetName} (\${targetEmail})</td></tr>
            <tr><td style="padding: 6px 0; color: #888;">Device:</td><td style="padding: 6px 0; color: #fff;">\${device}</td></tr>
          </table>
          <div style="text-align: center; margin: 24px 0;">
            <p style="color: #888; font-size: 12px; margin-bottom: 8px; letter-spacing: 1px;">VERIFICATION CODE (EXPIRES IN 10 MIN)</p>
            <div style="display: inline-block; background-color: #1a1a1a; border: 2px solid #D90429; border-radius: 8px; padding: 14px 28px; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #FFFFFF;">
              \${rawOtp}
            </div>
          </div>
        </div>
      </div>
    \`;

    await sendEmail({
      from: process.env.RESEND_SECURITY_FROM_EMAIL || notificationsFromEmail,
      to: targetEmail,
      subject: \`CodeXa — Your Account Verification Code (\${rawOtp})\`,
      html: emailHtml,
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      requiresVerification: true,
      requiresFounderApproval: true,
      challengeToken: rawChallengeToken,
      maskedTargetEmail: maskEmail(targetEmail),
      maskedFounderEmail: maskEmail(targetEmail),
      targetUser: {
        id: user.id,
        username: user.username,
        fullName: targetName,
        role: effectiveRole,
      },
    });
  } catch (err: any) {
    console.error("[POST /api/mobile/accounts/add/google/start]", err);
    return NextResponse.json(
      { ok: false, error: { code: "SERVER_ERROR", message: "Failed to initiate Google account addition." } },
      { status: 500 }
    );
  }
}
`;
fs.writeFileSync(addGooglePath, addGoogleCode, 'utf8');
console.log('Updated add/google/start/route.ts');

// 3. Update resend-otp/route.ts
const resendPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/mobile/accounts/resend-otp/route.ts');
let resendCode = `import { NextRequest, NextResponse } from "next/server";
import crypto from "crypto";
import { db } from "@/lib/db";
import { dataStore } from "@/lib/data-store";
import { getEffectiveRole } from "@/lib/permissions";
import { sendEmail, notificationsFromEmail } from "@/lib/email/client";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

function maskEmail(email: string): string {
  const [user, domain] = email.split("@");
  if (!user || !domain) return "***@codexa.agency";
  const maskedUser = user.length <= 2 ? user[0] + "***" : user[0] + "***" + user[user.length - 1];
  return \`\${maskedUser}@\${domain}\`;
}

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const { challengeToken } = body;

    if (!challengeToken) {
      return NextResponse.json(
        { ok: false, error: { code: "MISSING_CHALLENGE", message: "Challenge token is required." } },
        { status: 400 }
      );
    }

    const challengeTokenHash = crypto.createHash("sha256").update(challengeToken).digest("hex");
    const challenge = await db.preAuthChallenge.findUnique({
      where: { tokenHash: challengeTokenHash },
    });

    if (!challenge || challenge.expiresAt < new Date()) {
      return NextResponse.json(
        { ok: false, error: { code: "CHALLENGE_EXPIRED", message: "Verification session has expired. Please start over." } },
        { status: 400 }
      );
    }

    const user = await db.user.findUnique({
      where: { id: challenge.userId },
      include: { profile: true },
    });

    if (!user || !user.isActive) {
      return NextResponse.json(
        { ok: false, error: { code: "ACCOUNT_INACTIVE", message: "Account is inactive." } },
        { status: 403 }
      );
    }

    const targetEmail = user.email?.trim().toLowerCase();
    if (!targetEmail) {
      return NextResponse.json(
        { ok: false, error: { code: "NO_EMAIL", message: "No verified email found for this account." } },
        { status: 400 }
      );
    }

    // Invalidate previous OTPs
    await db.authOtp.updateMany({
      where: {
        userId: user.id,
        purpose: "ADD_MOBILE_ACCOUNT",
        isUsed: false,
      },
      data: { isUsed: true },
    });

    // Generate fresh OTP
    const rawOtp = crypto.randomInt(100000, 999999).toString();
    const otpHash = crypto.createHash("sha256").update(rawOtp).digest("hex");
    const expiresAt = new Date(Date.now() + 10 * 60 * 1000);

    await db.authOtp.create({
      data: {
        userId: user.id,
        email: targetEmail,
        otpHash,
        purpose: "ADD_MOBILE_ACCOUNT",
        attempts: 0,
        isUsed: false,
        expiresAt,
      },
    });

    const targetName = user.fullName || user.profile?.displayName || user.username;

    const emailHtml = \`
      <div style="font-family: Arial, sans-serif; background-color: #070707; color: #f7f7f7; padding: 32px; border-radius: 8px;">
        <div style="text-align: center; margin-bottom: 24px;">
          <h2 style="color: #FF1E3C; letter-spacing: 2px; margin: 0;">CODEXA SECURITY</h2>
          <p style="color: #a5a5a5; font-size: 13px; margin: 4px 0 0 0;">New Account Verification Code</p>
        </div>
        <div style="background-color: #111111; border: 1px solid rgba(217,4,41,0.3); border-radius: 8px; padding: 24px;">
          <p style="margin-top: 0; color: #e0e0e0; font-size: 15px;">
            Here is your new verification code for CodeXa account @\${user.username}:
          </p>
          <div style="text-align: center; margin: 24px 0;">
            <div style="display: inline-block; background-color: #1a1a1a; border: 2px solid #D90429; border-radius: 8px; padding: 14px 28px; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #FFFFFF;">
              \${rawOtp}
            </div>
          </div>
        </div>
      </div>
    \`;

    await sendEmail({
      from: process.env.RESEND_SECURITY_FROM_EMAIL || notificationsFromEmail,
      to: targetEmail,
      subject: \`CodeXa — New Verification Code (\${rawOtp})\`,
      html: emailHtml,
    }).catch(() => {});

    return NextResponse.json({
      ok: true,
      maskedTargetEmail: maskEmail(targetEmail),
      maskedFounderEmail: maskEmail(targetEmail),
    });
  } catch (err: any) {
    console.error("[POST /api/mobile/accounts/resend-otp]", err);
    return NextResponse.json(
      { ok: false, error: { code: "SERVER_ERROR", message: "Failed to resend code." } },
      { status: 500 }
    );
  }
}
`;
fs.writeFileSync(resendPath, resendCode, 'utf8');
console.log('Updated resend-otp/route.ts');
