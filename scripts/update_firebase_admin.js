const fs = require('fs');
const path = require('path');

const fbAdminPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/lib/firebase-admin.ts');
let content = fs.readFileSync(fbAdminPath, 'utf8');

const targetFunction = `export async function sendFcmPushToUser(
  userId: string,
  payload: { title: string; body: string; data?: Record<string, string> },
  options?: { targetConversationId?: string; excludeDeviceId?: string }
): Promise<{ success: boolean; sentCount: number; suppressedCount: number }> {
  try {
    const { db } = await import("@/lib/db");
    const sessions = await db.mobileSession.findMany({
      where: { userId, isRevoked: false, fcmToken: { not: null } },
      select: {
        id: true,
        deviceId: true,
        fcmToken: true,
        activeConversationId: true,
        activeConversationAt: true,
      },
    });

    if (!sessions || sessions.length === 0) {
      return { success: false, sentCount: 0, suppressedCount: 0 };
    }

    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    if (!clientEmail || !privateKey) return { success: false, sentCount: 0, suppressedCount: 0 };

    privateKey = privateKey.replace(/\\\\n/g, "\\n");
    const { getApps, initializeApp, cert } = await import("firebase-admin/app");
    const { getMessaging } = await import("firebase-admin/messaging");

    const existing = getApps();
    const app = existing.length > 0 && existing[0] ? existing[0] : initializeApp({
      credential: cert({
        projectId: process.env.FIREBASE_PROJECT_ID || "codxa-agency",
        clientEmail,
        privateKey,
      }),
    });

    const messaging = getMessaging(app);
    let sentCount = 0;
    let suppressedCount = 0;
    const now = Date.now();

    for (const session of sessions) {
      if (!session.fcmToken) continue;

      if (options?.excludeDeviceId && session.deviceId === options.excludeDeviceId) {
        suppressedCount++;
        continue;
      }

      // Smart Notification Suppression:
      // If the device is currently viewing the target conversation with a fresh heartbeat (< 60s),
      // suppress redundant notification on THIS device. Other devices of the same user still receive it!
      if (
        options?.targetConversationId &&
        session.activeConversationId === options.targetConversationId &&
        session.activeConversationAt &&
        now - new Date(session.activeConversationAt).getTime() < 60000
      ) {
        suppressedCount++;
        continue;
      }

      try {
        await messaging.send({
          token: session.fcmToken,
          notification: {
            title: payload.title,
            body: payload.body,
          },
          data: payload.data || {},
          android: {
            priority: "high",
            notification: {
              channelId: "codexa_messages_channel",
              sound: "default",
            },
          },
        });
        sentCount++;
      } catch (sendErr: any) {
        console.warn("[FCM send failed for token]:", sendErr?.code || sendErr?.message);
        if (
          sendErr?.code === "messaging/registration-token-not-registered" ||
          sendErr?.code === "messaging/invalid-registration-token"
        ) {
          await db.mobileSession.update({
            where: { id: session.id },
            data: { isRevoked: true },
          }).catch(() => {});
        }
      }
    }

    return { success: sentCount > 0, sentCount, suppressedCount };
  } catch (err: any) {
    console.error("[sendFcmPushToUser error]", err);
    return { success: false, sentCount: 0, suppressedCount: 0 };
  }
}`;

// Replace sendFcmPushToUser function in firebase-admin.ts
const funcStart = content.indexOf('export async function sendFcmPushToUser');
if (funcStart !== -1) {
  content = content.substring(0, funcStart) + targetFunction + '\n';
  fs.writeFileSync(fbAdminPath, content, 'utf8');
  console.log('Successfully updated sendFcmPushToUser in firebase-admin.ts');
} else {
  console.error('Could not find sendFcmPushToUser in firebase-admin.ts');
}
