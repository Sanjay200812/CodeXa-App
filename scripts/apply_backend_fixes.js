const fs = require('fs');
const path = require('path');

const portfolioDir = path.resolve('..', 'CodeXa', 'codexa-portfolio');

// 1. Update firebase-admin.ts with sendFcmPushToUser
const fbAdminPath = path.join(portfolioDir, 'src', 'lib', 'firebase-admin.ts');
let fbAdminContent = fs.readFileSync(fbAdminPath, 'utf8');
if (!fbAdminContent.includes('sendFcmPushToUser')) {
  const fcmCode = `
/**
 * Sends FCM push notification to all active devices of a user.
 */
export async function sendFcmPushToUser(
  userId: string,
  payload: { title: string; body: string; data?: Record<string, string> }
): Promise<{ success: boolean; sentCount: number }> {
  try {
    const { db } = await import("@/lib/db");
    const sessions = await db.mobileSession.findMany({
      where: { userId, isRevoked: false, fcmToken: { not: null } },
      select: { id: true, fcmToken: true },
    });

    if (!sessions || sessions.length === 0) {
      return { success: false, sentCount: 0 };
    }

    const clientEmail = process.env.FIREBASE_CLIENT_EMAIL;
    let privateKey = process.env.FIREBASE_PRIVATE_KEY;
    if (!clientEmail || !privateKey) return { success: false, sentCount: 0 };

    privateKey = privateKey.replace(/\\n/g, "\\n");
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

    for (const session of sessions) {
      if (!session.fcmToken) continue;
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

    return { success: sentCount > 0, sentCount };
  } catch (err: any) {
    console.error("[sendFcmPushToUser error]", err);
    return { success: false, sentCount: 0 };
  }
}
`;
  fbAdminContent += fcmCode;
  fs.writeFileSync(fbAdminPath, fbAdminContent, 'utf8');
  console.log('firebase-admin.ts updated successfully');
} else {
  console.log('firebase-admin.ts already contains sendFcmPushToUser');
}

// 2. Update devices/route.ts to accept and save fcmToken
const devicesPath = path.join(portfolioDir, 'src', 'app', 'api', 'mobile', 'devices', 'route.ts');
let devicesContent = fs.readFileSync(devicesPath, 'utf8');
devicesContent = devicesContent.replace(
  'const { deviceId, deviceName, platform = "ANDROID", appVersion = "1.0.0" } = body;',
  'const { deviceId, deviceName, platform = "ANDROID", appVersion = "1.0.0", fcmToken } = body;'
);
devicesContent = devicesContent.replace(
  `        appVersion,
        platform,
        lastActive: new Date(),`,
  `        appVersion,
        platform,
        fcmToken: fcmToken || undefined,
        lastActive: new Date(),`
);
devicesContent = devicesContent.replace(
  `        deviceId,
        deviceName: deviceName || "Android Mobile",`,
  `        deviceId,
        fcmToken: fcmToken || null,
        deviceName: deviceName || "Android Mobile",`
);
fs.writeFileSync(devicesPath, devicesContent, 'utf8');
console.log('devices/route.ts updated successfully');

// 3. Update src/app/api/chat/conversations/route.ts to include recipient in direct conversation response
const conversationsPath = path.join(portfolioDir, 'src', 'app', 'api', 'chat', 'conversations', 'route.ts');
let conversationsContent = fs.readFileSync(conversationsPath, 'utf8');
conversationsContent = conversationsContent.replace(
  `return NextResponse.json({ ok: true, conversation });`,
  `return NextResponse.json({
        ok: true,
        conversation: {
          ...conversation,
          type: "DIRECT",
          recipientUser: recipient,
        },
      });`
);
fs.writeFileSync(conversationsPath, conversationsContent, 'utf8');
console.log('conversations/route.ts updated successfully');

// 4. Update src/app/api/chat/conversations/[id]/route.ts
const convIdPath = path.join(portfolioDir, 'src', 'app', 'api', 'chat', 'conversations', '[id]', 'route.ts');
const newConvIdRoute = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";
import path from "path";
import fs from "fs";
import crypto from "crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat not configured" }, { status: 503 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const conversationId = resolvedParams.id;

  // Verify membership
  const { data: membership } = await chatSupabaseAdmin
    .from("conversation_members")
    .select("*")
    .eq("conversation_id", conversationId)
    .eq("core_user_id", user.id)
    .is("left_at", null)
    .maybeSingle();

  if (!membership) {
    return NextResponse.json({ ok: false, error: "Not a member of this conversation" }, { status: 403 });
  }

  const { data: conversation, error } = await chatSupabaseAdmin
    .from("conversations")
    .select("*, conversation_members(*)")
    .eq("id", conversationId)
    .single();

  if (error || !conversation) {
    return NextResponse.json({ ok: false, error: error?.message || "Not found" }, { status: 404 });
  }

  // Enhance member profiles from Core DB
  const memberCoreIds = (conversation.conversation_members || []).map((m: any) => m.core_user_id);
  const coreUsers = await prisma.user.findMany({
    where: { id: { in: memberCoreIds } },
    select: { id: true, fullName: true, username: true, role: true, profileMediaUrl: true },
  });

  return NextResponse.json({
    ok: true,
    conversation: {
      ...conversation,
      members: coreUsers,
    },
  });
}

export async function PATCH(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat not configured" }, { status: 503 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const conversationId = resolvedParams.id;

  // Retrieve conversation
  const { data: conv } = await chatSupabaseAdmin
    .from("conversations")
    .select("*, conversation_members(*)")
    .eq("id", conversationId)
    .maybeSingle();

  if (!conv) {
    return NextResponse.json({ ok: false, error: "Conversation not found" }, { status: 404 });
  }

  // Check that caller is a member
  const member = (conv.conversation_members || []).find((m: any) => m.core_user_id === user.id && !m.left_at);
  if (!member) {
    return NextResponse.json({ ok: false, error: "Not a member of this conversation" }, { status: 403 });
  }

  let title: string | undefined;
  let iconUrl: string | undefined;

  const contentType = req.headers.get("content-type") || "";
  if (contentType.includes("multipart/form-data")) {
    const formData = await req.formData();
    title = (formData.get("title") as string) || undefined;
    const file = formData.get("file") as File | null;
    if (file && file.size > 0) {
      const bytes = await file.arrayBuffer();
      const buffer = Buffer.from(bytes);
      const ext = path.extname(file.name) || ".jpg";
      const filename = \`group_\${conversationId}_\${Date.now()}_\${crypto.randomBytes(4).toString("hex")}\${ext}\`;
      const uploadsDir = path.join(process.cwd(), "public", "uploads", "groups");
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      fs.writeFileSync(path.join(uploadsDir, filename), buffer);
      iconUrl = \`https://codxa-agency.online/uploads/groups/\${filename}\`;
    }
  } else {
    const body = await req.json().catch(() => ({}));
    title = body.title;
    iconUrl = body.iconUrl || body.avatarUrl;

    if (body.base64) {
      const cleanBase64 = body.base64.replace(/^data:[^;]+;base64,/, "");
      const buffer = Buffer.from(cleanBase64, "base64");
      const filename = \`group_\${conversationId}_\${Date.now()}_\${crypto.randomBytes(4).toString("hex")}.jpg\`;
      const uploadsDir = path.join(process.cwd(), "public", "uploads", "groups");
      if (!fs.existsSync(uploadsDir)) {
        fs.mkdirSync(uploadsDir, { recursive: true });
      }
      fs.writeFileSync(path.join(uploadsDir, filename), buffer);
      iconUrl = \`https://codxa-agency.online/uploads/groups/\${filename}\`;
    }
  }

  // Group avatar validation: only group conversations have group icons
  if (iconUrl && conv.type !== "GROUP") {
    return NextResponse.json({
      ok: false,
      error: "Only group conversations can have a group icon.",
    }, { status: 400 });
  }

  const existingMeta = conv.metadata || {};
  const updatedMeta = {
    ...existingMeta,
    ...(iconUrl ? { iconUrl, avatarUrl: iconUrl } : {}),
  };

  const updatePayload: any = {
    updated_at: new Date().toISOString(),
    metadata: updatedMeta,
  };
  if (title !== undefined) updatePayload.title = title;

  const { data: updatedConv } = await chatSupabaseAdmin
    .from("conversations")
    .update(updatePayload)
    .eq("id", conversationId)
    .select()
    .single();

  return NextResponse.json({
    ok: true,
    message: "Conversation updated successfully.",
    conversation: {
      ...(updatedConv || conv),
      icon_url: iconUrl || existingMeta.iconUrl,
      avatar_url: iconUrl || existingMeta.avatarUrl,
    },
    iconUrl,
  });
}
`;
fs.writeFileSync(convIdPath, newConvIdRoute, 'utf8');
console.log('conversations/[id]/route.ts updated successfully');

// 5. Update src/app/api/chat/upload/route.ts
const uploadPath = path.join(portfolioDir, 'src', 'app', 'api', 'chat', 'upload', 'route.ts');
const newUploadRoute = `/**
 * POST /api/chat/upload
 * Secure Chat Media Upload endpoint supporting Bearer auth and multipart files.
 */
import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";
import path from "path";
import fs from "fs";
import crypto from "crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(req: NextRequest) {
  try {
    const user = await getAuthUserFromRequest(req);
    if (!user) {
      return NextResponse.json({ success: false, ok: false, error: "Unauthorized. Please log in." }, { status: 401 });
    }

    const formData = await req.formData();
    const file = formData.get("file") as File | null;
    const conversationId = formData.get("conversationId") as string | null;

    if (!file) {
      return NextResponse.json({ success: false, ok: false, error: "No media file provided." }, { status: 400 });
    }

    if (!conversationId) {
      return NextResponse.json({ success: false, ok: false, error: "conversationId is required." }, { status: 400 });
    }

    if (isChatConfigured() && chatSupabaseAdmin) {
      const { data: membership } = await chatSupabaseAdmin
        .from("conversation_members")
        .select("id")
        .eq("conversation_id", conversationId)
        .eq("core_user_id", user.id)
        .is("left_at", null)
        .maybeSingle();

      if (!membership) {
        return NextResponse.json({ success: false, ok: false, error: "Forbidden: You are not a member of this conversation." }, { status: 403 });
      }
    }

    const buffer = Buffer.from(await file.arrayBuffer());
    const ext = path.extname(file.name) || ".jpg";
    const filename = \`chat_\${conversationId}_\${Date.now()}_\${crypto.randomBytes(4).toString("hex")}\${ext}\`;
    const uploadsDir = path.join(process.cwd(), "public", "uploads", "chat");
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    fs.writeFileSync(path.join(uploadsDir, filename), buffer);

    const publicUrl = \`https://codxa-agency.online/uploads/chat/\${filename}\`;

    return NextResponse.json({
      success: true,
      ok: true,
      url: publicUrl,
      attachment: {
        id: \`att-\${Date.now()}\`,
        url: publicUrl,
        name: file.name,
        mimeType: file.type,
        size: file.size,
      },
    });
  } catch (err: any) {
    console.error("[POST /api/chat/upload]", err);
    return NextResponse.json({ success: false, ok: false, error: "Failed to upload media." }, { status: 500 });
  }
}
`;
fs.writeFileSync(uploadPath, newUploadRoute, 'utf8');
console.log('upload/route.ts updated successfully');

// 6. Update src/app/api/chat/messages/route.ts
const messagesRoutePath = path.join(portfolioDir, 'src', 'app', 'api', 'chat', 'messages', 'route.ts');
const newMessagesRoute = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import {
  chatSupabaseAdmin,
  sendChatMessage,
  isChatConfigured
} from "@/lib/supabase/chat-admin";
import path from "path";
import fs from "fs";
import crypto from "crypto";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function GET(req: NextRequest) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: true, messages: [] });
  }

  const { searchParams } = new URL(req.url);
  const conversationId = searchParams.get("conversationId");
  if (!conversationId) {
    return NextResponse.json({ ok: false, error: "conversationId required" }, { status: 400 });
  }

  const before = searchParams.get("before");
  const limit = Math.min(Number(searchParams.get("limit")) || 30, 50);

  // Check membership
  const { data: membership } = await chatSupabaseAdmin
    .from("conversation_members")
    .select("id")
    .eq("conversation_id", conversationId)
    .eq("core_user_id", user.id)
    .is("left_at", null)
    .maybeSingle();

  if (!membership) {
    return NextResponse.json({ ok: false, error: "Forbidden" }, { status: 403 });
  }

  let query = chatSupabaseAdmin
    .from("messages")
    .select("*, message_reads(*), message_reactions(*), message_attachments(*)")
    .eq("conversation_id", conversationId)
    .order("created_at", { ascending: false })
    .limit(limit);

  if (before) {
    query = query.lt("created_at", before);
  }

  const { data: messages, error } = await query;
  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  // Enhance messages with sender profiles for group clarity
  const senderIds = Array.from(new Set((messages || []).map((m: any) => m.sender_core_user_id)));
  const senders = await prisma.user.findMany({
    where: { id: { in: senderIds } },
    select: { id: true, fullName: true, username: true, role: true, profileMediaUrl: true },
  });
  const senderMap = new Map(senders.map((s) => [s.id, s]));

  return NextResponse.json({
    ok: true,
    success: true,
    messages: (messages || []).map((m: any) => {
      const mediaUrl =
        m.message_attachments?.[0]?.file_url ||
        m.message_attachments?.[0]?.url ||
        (m.message_type === "IMAGE" && m.text?.startsWith("http") ? m.text : null) ||
        (m.text?.startsWith("data:image") ? m.text : null);

      const senderProfile = senderMap.get(m.sender_core_user_id);

      return {
        ...m,
        message: m.text,
        senderId: m.sender_core_user_id,
        senderName: senderProfile?.fullName || senderProfile?.username || "Colleague",
        senderAvatar: senderProfile?.profileMediaUrl || null,
        mediaUrl: mediaUrl || undefined,
      };
    }),
  });
}

export async function POST(req: NextRequest) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat service unavailable" }, { status: 503 });
  }

  try {
    const body = await req.json();
    const conversationId = body.conversationId;
    let text = body.text || body.message || "";
    const clientMessageId = body.clientMessageId || body.clientId;
    let messageType = body.messageType || "TEXT";
    const replyToMessageId = body.replyToMessageId;
    const mediaUrlInput = body.mediaUrl;

    if (!conversationId) {
      return NextResponse.json({ ok: false, error: "conversationId required" }, { status: 400 });
    }

    if (!clientMessageId) {
      return NextResponse.json({ ok: false, error: "clientMessageId required" }, { status: 400 });
    }

    // Handle base64 image or mediaUrl upload
    let savedMediaUrl = "";
    if (mediaUrlInput && typeof mediaUrlInput === "string") {
      messageType = "IMAGE";
      if (mediaUrlInput.startsWith("data:image")) {
        try {
          const match = mediaUrlInput.match(/^data:image\\/([a-zA-Z0-9]+);base64,(.+)$/);
          if (match) {
            const ext = match[1] === "jpeg" ? "jpg" : match[1];
            const cleanBase64 = match[2];
            const buffer = Buffer.from(cleanBase64, "base64");
            const filename = \`chat_\${conversationId}_\${Date.now()}_\${crypto.randomBytes(4).toString("hex")}.\${ext}\`;
            const uploadsDir = path.join(process.cwd(), "public", "uploads", "chat");
            if (!fs.existsSync(uploadsDir)) {
              fs.mkdirSync(uploadsDir, { recursive: true });
            }
            fs.writeFileSync(path.join(uploadsDir, filename), buffer);
            savedMediaUrl = \`https://codxa-agency.online/uploads/chat/\${filename}\`;
            text = text && text !== "[Image Attached]" ? text : savedMediaUrl;
          }
        } catch (mediaErr) {
          console.warn("[Media base64 save warning]", mediaErr);
        }
      } else if (mediaUrlInput.startsWith("http")) {
        savedMediaUrl = mediaUrlInput;
        text = text && text !== "[Image Attached]" ? text : savedMediaUrl;
      }
    }

    if (!text && messageType === "TEXT") {
      return NextResponse.json({ ok: false, error: "Message text cannot be empty" }, { status: 400 });
    }

    const result = await sendChatMessage({
      conversationId,
      senderCoreUserId: user.id,
      clientMessageId,
      text: text || savedMediaUrl || "[Attachment]",
      messageType,
      replyToMessageId,
    });

    if (result.error) {
      return NextResponse.json({ ok: false, error: result.error }, { status: 400 });
    }

    // If media was saved, record in message_attachments
    if (savedMediaUrl && result.data?.id) {
      try {
        await chatSupabaseAdmin.from("message_attachments").insert({
          message_id: result.data.id,
          file_url: savedMediaUrl,
          file_type: "image",
        });
      } catch (_) {}
    }

    // Trigger Core notification and FCM Push if newly inserted
    if (!result.isDuplicate && result.data) {
      const { data: members } = await chatSupabaseAdmin
        .from("conversation_members")
        .select("core_user_id, muted")
        .eq("conversation_id", conversationId)
        .neq("core_user_id", user.id)
        .is("left_at", null);

      if (members && members.length > 0) {
        for (const m of members) {
          if (!m.muted) {
            try {
              await prisma.notification.create({
                data: {
                  userId: m.core_user_id,
                  type: "CHAT",
                  title: \`Message from \${user.fullName || user.username || "Colleague"}\`,
                  message: (text || "Sent an attachment").slice(0, 120),
                  link: \`/messages/\${conversationId}\`,
                },
              });
            } catch (_) {}

            // Send real FCM push alert
            try {
              const { sendFcmPushToUser } = await import("@/lib/firebase-admin");
              await sendFcmPushToUser(m.core_user_id, {
                title: user.fullName || user.username || "CodeXa Message",
                body: messageType === "IMAGE" ? "📷 Sent a photo" : (text || "New message").slice(0, 100),
                data: {
                  conversationId,
                  senderId: user.id,
                  type: "CHAT",
                },
              });
            } catch (_) {}
          }
        }
      }
    }

    return NextResponse.json({
      ok: true,
      success: true,
      message: {
        ...result.data,
        message: result.data.text,
        senderId: result.data.sender_core_user_id,
        mediaUrl: savedMediaUrl || (result.data.message_type === "IMAGE" ? result.data.text : null),
      },
      isDuplicate: result.isDuplicate,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(messagesRoutePath, newMessagesRoute, 'utf8');
console.log('messages/route.ts updated successfully');
console.log('All backend fixes applied cleanly!');
