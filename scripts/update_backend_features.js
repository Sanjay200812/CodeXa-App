const fs = require('fs');
const path = require('path');

const portfolioDir = 'G:/AntiGravity IDE/CodeXa/codexa-portfolio';

// --- 1. Update src/app/api/chat/messages/route.ts ---
const messagesRoutePath = path.join(portfolioDir, 'src/app/api/chat/messages/route.ts');
const messagesRouteContent = `import { saveMediaUpload } from '@/lib/media-storage';
import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import {
  chatSupabaseAdmin,
  sendChatMessage,
  isChatConfigured
} from "@/lib/supabase/chat-admin";
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
  const limit = Math.min(Number(searchParams.get("limit")) || 40, 60);

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

  // Enhance messages with sender profiles for identity resolution
  const senderIds: string[] = Array.from(new Set((messages || []).map((m: any) => String(m.sender_core_user_id))));
  const senders = await prisma.user.findMany({
    where: { id: { in: senderIds } },
    select: {
      id: true,
      fullName: true,
      username: true,
      role: true,
      profileMediaUrl: true,
      profile: { select: { displayName: true, mediaUrl: true } }
    },
  });
  const senderMap = new Map(senders.map((s) => [s.id, s]));

  // Also query view once sessions if any messages are view once
  const viewOnceMsgIds = (messages || [])
    .filter((m: any) => m.is_view_once || m.message_type?.startsWith("VIEW_ONCE"))
    .map((m: any) => m.id);

  let userVoConsumedMap = new Map<string, boolean>();
  if (viewOnceMsgIds.length > 0) {
    const { data: voSessions } = await chatSupabaseAdmin
      .from("message_view_once_sessions")
      .select("message_id, status")
      .in("message_id", viewOnceMsgIds)
      .eq("viewer_core_user_id", user.id);

    (voSessions || []).forEach((s: any) => {
      userVoConsumedMap.set(s.message_id, s.status === "CONSUMED");
    });
  }

  return NextResponse.json({
    ok: true,
    success: true,
    messages: (messages || []).map((m: any) => {
      const isVO = m.is_view_once === true || m.message_type === "VIEW_ONCE_IMAGE" || m.message_type === "VIEW_ONCE_VIDEO";
      const isMe = m.sender_core_user_id === user.id;
      const isConsumed = isVO && !isMe && (m.view_once_consumed || userVoConsumedMap.get(m.id) === true);

      let mediaUrl =
        m.message_attachments?.[0]?.file_url ||
        m.message_attachments?.[0]?.url ||
        ((m.message_type === "IMAGE" || m.message_type === "VIEW_ONCE_IMAGE") && m.text?.startsWith("http") ? m.text : null) ||
        (m.text?.startsWith("data:image") ? m.text : null);

      if (isConsumed) {
        mediaUrl = null; // Don't expose consumed view-once bytes
      }

      const senderProfile = senderMap.get(m.sender_core_user_id);
      const senderDisplayName =
        senderProfile?.fullName ||
        senderProfile?.profile?.displayName ||
        senderProfile?.username ||
        "Colleague";

      const reactionsList = (m.message_reactions || []).map((r: any) => r.reaction || r.emoji || "❤️");

      return {
        ...m,
        message: isConsumed ? "[Photo Opened]" : m.text,
        text: isConsumed ? "[Photo Opened]" : m.text,
        senderId: m.sender_core_user_id,
        senderName: senderDisplayName,
        senderAvatar: senderProfile?.profileMediaUrl || senderProfile?.profile?.mediaUrl || null,
        mediaUrl: mediaUrl || undefined,
        reactions: reactionsList,
        reactionDetails: m.message_reactions || [],
        isViewOnce: isVO,
        viewOnceConsumed: isConsumed,
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
    const stickerId = body.stickerId;
    const catalogVersion = body.catalogVersion;
    const isViewOnce = body.isViewOnce === true;

    if (stickerId || messageType === "STICKER") {
      messageType = "STICKER";
      if (stickerId) text = stickerId;
    }

    const replyToMessageId = body.replyToMessageId;
    const mediaUrlInput = body.mediaUrl;

    if (!conversationId) {
      return NextResponse.json({ ok: false, error: "conversationId required" }, { status: 400 });
    }

    if (!clientMessageId) {
      return NextResponse.json({ ok: false, error: "clientMessageId required" }, { status: 400 });
    }

    // Handle base64 image/video or mediaUrl upload
    let savedMediaUrl = "";
    if (mediaUrlInput && typeof mediaUrlInput === "string") {
      const isVideo = mediaUrlInput.startsWith("data:video") || messageType === "VIDEO" || messageType === "VIEW_ONCE_VIDEO";
      
      if (isViewOnce) {
        messageType = isVideo ? "VIEW_ONCE_VIDEO" : "VIEW_ONCE_IMAGE";
      } else {
        messageType = isVideo ? "VIDEO" : "IMAGE";
      }

      if (mediaUrlInput.startsWith("data:")) {
        try {
          const dataUriMatch = mediaUrlInput.match(/^data:([^;]+);base64,(.+)$/);
          if (dataUriMatch) {
            const mime = dataUriMatch[1];
            const cleanBase64 = dataUriMatch[2];
            const buffer = Buffer.from(cleanBase64, "base64");
            const ext = mime.includes("video") ? ".mp4" : (mime.includes("png") ? ".png" : ".jpg");
            const filename = \`chat_\${conversationId}_\${Date.now()}_\${crypto.randomBytes(4).toString("hex")}\${ext}\`;
            
            const uploadRes = await saveMediaUpload("chat-media", buffer, filename, mime, conversationId);
            savedMediaUrl = uploadRes.publicUrl;
            text = text && text !== "[Image Attached]" && text !== "[Video Attached]" ? text : savedMediaUrl;
          }
        } catch (mediaErr) {
          console.warn("[Chat media save warning]", mediaErr);
        }
      } else if (mediaUrlInput.startsWith("http")) {
        savedMediaUrl = mediaUrlInput;
        text = text && text !== "[Image Attached]" && text !== "[Video Attached]" ? text : savedMediaUrl;
      }
    }

    if (isViewOnce && !messageType.startsWith("VIEW_ONCE")) {
      messageType = messageType === "VIDEO" ? "VIEW_ONCE_VIDEO" : "VIEW_ONCE_IMAGE";
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

    // Set view once flags on message row
    if (isViewOnce && result.data?.id) {
      try {
        await chatSupabaseAdmin
          .from("messages")
          .update({ is_view_once: true })
          .eq("id", result.data.id);
      } catch (_) {}
    }

    // If media was saved, record in message_attachments
    if (savedMediaUrl && result.data?.id) {
      try {
        await chatSupabaseAdmin.from("message_attachments").insert({
          message_id: result.data.id,
          file_url: savedMediaUrl,
          file_type: messageType.includes("VIDEO") ? "video" : "image",
        });
      } catch (_) {}
    }

    // Fetch conversation details for group title & members
    const { data: convData } = await chatSupabaseAdmin
      .from("conversations")
      .select("id, type, title")
      .eq("id", conversationId)
      .single();

    const isGroup = convData?.type === "GROUP";
    const groupName = convData?.title || "Team Group";

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
            const senderDisplayName = user.displayName || user.username || "Colleague";
            let pushTitle = senderDisplayName;
            let pushBody = text.slice(0, 100);

            if (isViewOnce) {
              pushBody = "🔒 Sent a View Once photo";
            } else if (messageType === "STICKER") {
              pushBody = "🎨 Sent a sticker";
            } else if (messageType === "IMAGE") {
              pushBody = "📷 Sent a photo";
            } else if (messageType === "VIDEO") {
              pushBody = "🎥 Sent a video";
            }

            if (isGroup) {
              pushTitle = groupName;
              pushBody = \`\${senderDisplayName}: \${pushBody}\`;
            }

            try {
              await prisma.notification.create({
                data: {
                  userId: m.core_user_id,
                  type: "CHAT",
                  title: pushTitle,
                  message: pushBody.slice(0, 120),
                  link: \`/messages/\${conversationId}\`,
                },
              });
            } catch (_) {}

            // Send FCM push alert with complete metadata
            try {
              const { sendFcmPushToUser } = await import("@/lib/firebase-admin");
              await sendFcmPushToUser(m.core_user_id, {
                title: pushTitle,
                body: pushBody,
                data: {
                  conversationId,
                  messageId: String(result.data.id),
                  senderId: user.id,
                  senderName: senderDisplayName,
                  type: "CHAT",
                  messageType,
                  mediaUrl: isViewOnce ? "" : (savedMediaUrl || ""),
                  stickerId: messageType === "STICKER" ? (stickerId || text) : "",
                  isGroup: isGroup ? "true" : "false",
                  groupName: isGroup ? groupName : "",
                },
              });
            } catch (fcmErr) {
              console.warn("[FCM PUSH ERROR]", fcmErr);
            }
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
        isViewOnce,
        reactions: [],
      },
      isDuplicate: result.isDuplicate,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(messagesRoutePath, messagesRouteContent, 'utf8');
console.log('Updated:', messagesRoutePath);

// --- 2. Update src/app/api/chat/messages/[id]/reactions/route.ts ---
const reactionsRoutePath = path.join(portfolioDir, 'src/app/api/chat/messages/[id]/reactions/route.ts');
const reactionsRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const messageId = resolvedParams.id;

  const body = await req.json().catch(() => ({}));
  const reaction = body.reaction || body.emoji || "❤️";

  // Check if this reaction from this user already exists
  const { data: existing } = await chatSupabaseAdmin
    .from("message_reactions")
    .select("id, reaction")
    .eq("message_id", messageId)
    .eq("core_user_id", user.id)
    .maybeSingle();

  if (existing) {
    if (existing.reaction === reaction) {
      // Toggle off / delete reaction
      await chatSupabaseAdmin
        .from("message_reactions")
        .delete()
        .eq("id", existing.id);

      return NextResponse.json({ ok: true, toggled: false, messageId });
    } else {
      // Update to new reaction
      await chatSupabaseAdmin
        .from("message_reactions")
        .update({ reaction, created_at: new Date().toISOString() })
        .eq("id", existing.id);

      return NextResponse.json({ ok: true, toggled: true, reaction, messageId });
    }
  }

  // Insert reaction
  const { data, error } = await chatSupabaseAdmin
    .from("message_reactions")
    .insert({
      message_id: messageId,
      core_user_id: user.id,
      reaction,
    })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, toggled: true, reaction: data, messageId });
}
`;
fs.writeFileSync(reactionsRoutePath, reactionsRouteContent, 'utf8');
console.log('Updated:', reactionsRoutePath);

// --- 3. Create src/app/api/chat/messages/[id]/view-once/route.ts ---
const voDir = path.join(portfolioDir, 'src/app/api/chat/messages/[id]/view-once');
if (!fs.existsSync(voDir)) fs.mkdirSync(voDir, { recursive: true });
const voRoutePath = path.join(voDir, 'route.ts');
const voRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

export async function POST(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const messageId = resolvedParams.id;

  // Retrieve message
  const { data: msg, error: msgErr } = await chatSupabaseAdmin
    .from("messages")
    .select("*, message_attachments(*)")
    .eq("id", messageId)
    .maybeSingle();

  if (msgErr || !msg) {
    return NextResponse.json({ ok: false, error: "Message not found" }, { status: 404 });
  }

  const isVO = msg.is_view_once || msg.message_type?.startsWith("VIEW_ONCE");
  if (!isVO) {
    return NextResponse.json({ ok: false, error: "Not a view once message" }, { status: 400 });
  }

  // Sender can view own message
  if (msg.sender_core_user_id === user.id) {
    const mediaUrl = msg.message_attachments?.[0]?.file_url || msg.text;
    return NextResponse.json({ ok: true, mediaUrl, isOwner: true });
  }

  // Check if session is already consumed
  const { data: session } = await chatSupabaseAdmin
    .from("message_view_once_sessions")
    .select("*")
    .eq("message_id", messageId)
    .eq("viewer_core_user_id", user.id)
    .maybeSingle();

  if (session && session.status === "CONSUMED") {
    return NextResponse.json({
      ok: false,
      code: "VIEW_ONCE_CONSUMED",
      error: "This media has already been viewed and can no longer be opened.",
    }, { status: 410 });
  }

  const now = new Date().toISOString();

  // Atomically record session as CONSUMED
  await chatSupabaseAdmin
    .from("message_view_once_sessions")
    .upsert({
      message_id: messageId,
      viewer_core_user_id: user.id,
      status: "CONSUMED",
      opened_at: now,
      consumed_at: now,
    }, { onConflict: "message_id,viewer_core_user_id" });

  // Update message row
  await chatSupabaseAdmin
    .from("messages")
    .update({
      view_once_consumed: true,
      view_once_consumed_at: now,
    })
    .eq("id", messageId);

  const mediaUrl = msg.message_attachments?.[0]?.file_url || msg.text;

  return NextResponse.json({
    ok: true,
    mediaUrl,
    openedAt: now,
  });
}
`;
fs.writeFileSync(voRoutePath, voRouteContent, 'utf8');
console.log('Created:', voRoutePath);

// --- 4. Update src/app/api/mobile/stories/route.ts (Seen state + post_views) ---
const storiesRoutePath = path.join(portfolioDir, 'src/app/api/mobile/stories/route.ts');
const storiesRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult, generateRequestId } from "@/lib/auth";
import { saveMediaUpload } from "@/lib/media-storage";
import { formatProfileMediaUrl } from "@/lib/profile-media";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const NO_CACHE_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
  Pragma: "no-cache",
  Expires: "0",
};

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function GET(req: NextRequest) {
  try {
    const user = await resolveRequestUser(req);
    if (!user) {
      return NextResponse.json({ ok: false, error: { code: "UNAUTHORIZED", message: "Unauthorized." } }, { status: 401, headers: NO_CACHE_HEADERS });
    }

    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const rawStories = await db.post.findMany({
      where: {
        isDeleted: false,
        createdAt: { gte: twentyFourHoursAgo },
        content: { startsWith: "[CODEXA_STORY" },
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            username: true,
            role: true,
            profileMediaUrl: true,
            profile: true,
          },
        },
        media: true,
        likes: {
          select: { userId: true },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    // Query user's viewed story post IDs from post_views table
    const storyIds = rawStories.map(s => s.id);
    let viewedStorySet = new Set<string>();
    if (storyIds.length > 0) {
      const views = await db.$queryRawUnsafe<Array<{ post_id: string }>>(
        \`SELECT post_id FROM post_views WHERE user_id = $1 AND post_id = ANY($2)\`,
        user.id,
        storyIds
      ).catch(() => []);
      views.forEach(v => viewedStorySet.add(v.post_id));
    }

    const authorMap = new Map<string, {
      authorId: string;
      authorName: string;
      username: string;
      avatarUrl: string | null;
      role: string;
      isOwnStory: boolean;
      hasUnseen: boolean;
      items: Array<{
        id: string;
        type: string;
        caption: string;
        mediaUrl?: string | null;
        createdAt: string;
        expiresAt: string;
        isViewed: boolean;
        isLiked: boolean;
        likesCount: number;
      }>;
    }>();

    for (const post of rawStories) {
      const author = post.author;
      if (!author) continue;

      let storyType = "TEXT";
      let audience = "EVERYONE";
      let caption = post.content;

      const tagMatch = post.content.match(/^\[CODEXA_STORY:([^:]+):([^\]]+)\]\\n?([\\s\\S]*)$/);
      if (tagMatch) {
        storyType = tagMatch[1];
        audience = tagMatch[2];
        caption = tagMatch[3].trim();
      }

      if (!authorMap.has(author.id)) {
        authorMap.set(author.id, {
          authorId: author.id,
          authorName: author.fullName || author.username,
          username: author.username,
          avatarUrl: formatProfileMediaUrl(author.profileMediaUrl || author.profile?.profileMediaUrl || author.profile?.mediaUrl),
          role: author.role,
          isOwnStory: author.id === user.id,
          hasUnseen: false,
          items: [],
        });
      }

      const isViewed = author.id === user.id || viewedStorySet.has(post.id);
      const isLiked = (post.likes || []).some(l => l.userId === user.id);
      const likesCount = post.likes?.length || 0;

      authorMap.get(author.id)!.items.push({
        id: post.id,
        type: storyType,
        caption,
        mediaUrl: post.media?.[0]?.mediaUrl || null,
        createdAt: post.createdAt.toISOString(),
        expiresAt: new Date(post.createdAt.getTime() + 24 * 60 * 60 * 1000).toISOString(),
        isViewed,
        isLiked,
        likesCount,
      });
    }

    // Determine hasUnseen per author accurately
    authorMap.forEach(group => {
      if (group.isOwnStory) {
        group.hasUnseen = false;
      } else {
        group.hasUnseen = group.items.some(it => !it.isViewed);
      }
    });

    const stories = Array.from(authorMap.values()).sort((a, b) => {
      if (a.isOwnStory) return -1;
      if (b.isOwnStory) return 1;
      if (a.hasUnseen && !b.hasUnseen) return -1;
      if (!a.hasUnseen && b.hasUnseen) return 1;
      return 0;
    });

    return NextResponse.json({
      ok: true,
      stories,
      count: stories.length,
    }, { headers: NO_CACHE_HEADERS });

  } catch (err: any) {
    console.error("[GET /api/mobile/stories]", err);
    return NextResponse.json({ ok: false, error: { code: "SERVER_ERROR", message: "Failed to load stories." } }, { status: 500, headers: NO_CACHE_HEADERS });
  }
}

export async function POST(req: NextRequest) {
  const requestId = generateRequestId();

  try {
    const user = await resolveRequestUser(req);
    if (!user) {
      return NextResponse.json({ ok: false, error: { code: "UNAUTHORIZED", message: "Unauthorized." } }, { status: 401, headers: NO_CACHE_HEADERS });
    }

    let type = "TEXT";
    let content = "";
    let mediaUrl: string | null = null;
    let audience = "EVERYONE";

    const contentType = req.headers.get("content-type") || "";

    if (contentType.includes("multipart/form-data")) {
      const formData = await req.formData();
      type = (formData.get("type") as string) || "TEXT";
      content = (formData.get("content") as string) || "";
      audience = (formData.get("audience") as string) || "EVERYONE";

      const file = formData.get("file") as File | null;
      if (file && file.size > 0) {
        const bytes = await file.arrayBuffer();
        const buffer = Buffer.from(bytes);
        const uploadRes = await saveMediaUpload(
          "stories",
          buffer,
          file.name || "story.jpg",
          file.type || (type === "VIDEO" ? "video/mp4" : "image/jpeg"),
          user.id
        );
        mediaUrl = uploadRes.publicUrl;
      }
    } else {
      const body = await req.json().catch(() => ({}));
      type = body.type || "TEXT";
      content = body.content || "";
      mediaUrl = body.mediaUrl || null;
      audience = body.audience || "EVERYONE";

      if (body.base64) {
        const cleanBase64 = body.base64.replace(/^data:[^;]+;base64,/, "");
        const buffer = Buffer.from(cleanBase64, "base64");
        const isVideo = type === "VIDEO" || body.isVideo === true;
        const uploadRes = await saveMediaUpload(
          "stories",
          buffer,
          isVideo ? "story.mp4" : "story.jpg",
          isVideo ? "video/mp4" : "image/jpeg",
          user.id
        );
        mediaUrl = uploadRes.publicUrl;
      }
    }

    const validTypes = ["TEXT", "IMAGE", "VIDEO", "PROJECT_UPDATE", "ANNOUNCEMENT", "MILESTONE"];
    const normalizedType = validTypes.includes(type.toUpperCase()) ? type.toUpperCase() : "TEXT";

    if (!content.trim() && !mediaUrl) {
      return NextResponse.json({ ok: false, error: { code: "BAD_REQUEST", message: "Story content or media is required." } }, { status: 400, headers: NO_CACHE_HEADERS });
    }

    const storyContent = \`[CODEXA_STORY:\${normalizedType}:\${audience}]\\n\${content.trim()}\`;

    const post = await db.post.create({
      data: {
        authorId: user.id,
        content: storyContent,
        isAnnouncement: normalizedType === "ANNOUNCEMENT",
        media: mediaUrl ? {
          create: [{
            mediaUrl,
            mediaType: normalizedType === "VIDEO" ? "video/mp4" : "image/jpeg",
          }],
        } : undefined,
      },
      include: {
        author: {
          select: { id: true, fullName: true, username: true, role: true, profileMediaUrl: true },
        },
        media: true,
      },
    });

    // Notify team members about new story (without spamming)
    try {
      const teamUsers = await db.user.findMany({
        where: { id: { not: user.id }, isActive: true },
        select: { id: true },
        take: 30,
      });

      for (const tUser of teamUsers) {
        await db.notification.create({
          data: {
            userId: tUser.id,
            type: "SOCIAL",
            title: \`\${user.displayName || "A teammate"} posted a new Story\`,
            message: content.trim().slice(0, 80) || "Check out the latest story on CodeXa",
            link: \`/stories?storyId=\${post.id}\`,
          },
        }).catch(() => {});
      }
    } catch (_) {}

    return NextResponse.json({
      ok: true,
      message: "Story created successfully.",
      story: {
        id: post.id,
        type: normalizedType,
        caption: content.trim(),
        mediaUrl: post.media?.[0]?.mediaUrl || mediaUrl || null,
        createdAt: post.createdAt.toISOString(),
        expiresAt: new Date(post.createdAt.getTime() + 24 * 60 * 60 * 1000).toISOString(),
        isViewed: true,
        isLiked: false,
        likesCount: 0,
      },
    }, { headers: NO_CACHE_HEADERS });

  } catch (err: any) {
    console.error("[POST /api/mobile/stories] [\${requestId}]", err);
    return NextResponse.json({ ok: false, error: { code: "SERVER_ERROR", message: "Failed to publish story." } }, { status: 500, headers: NO_CACHE_HEADERS });
  }
}
`;
fs.writeFileSync(storiesRoutePath, storiesRouteContent, 'utf8');
console.log('Updated:', storiesRoutePath);

// --- 5. Create src/app/api/mobile/stories/[id]/view/route.ts ---
const storyViewDir = path.join(portfolioDir, 'src/app/api/mobile/stories/[id]/view');
if (!fs.existsSync(storyViewDir)) fs.mkdirSync(storyViewDir, { recursive: true });
const storyViewRoutePath = path.join(storyViewDir, 'route.ts');
const storyViewRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function POST(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await resolveRequestUser(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const storyId = resolvedParams.id;

  try {
    const viewId = \`pv_\${storyId}_\${user.id}\`;
    await db.$executeRawUnsafe(
      \`INSERT INTO post_views (id, post_id, user_id, created_at) VALUES ($1, $2, $3, NOW()) ON CONFLICT (post_id, user_id) DO NOTHING\`,
      viewId,
      storyId,
      user.id
    );

    return NextResponse.json({ ok: true, storyId, viewed: true });
  } catch (err: any) {
    console.error("[POST /api/mobile/stories/[id]/view]", err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(storyViewRoutePath, storyViewRouteContent, 'utf8');
console.log('Created:', storyViewRoutePath);

// --- 6. Create src/app/api/mobile/stories/[id]/like/route.ts ---
const storyLikeDir = path.join(portfolioDir, 'src/app/api/mobile/stories/[id]/like');
if (!fs.existsSync(storyLikeDir)) fs.mkdirSync(storyLikeDir, { recursive: true });
const storyLikeRoutePath = path.join(storyLikeDir, 'route.ts');
const storyLikeRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function POST(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await resolveRequestUser(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const storyId = resolvedParams.id;

  try {
    const existing = await db.postLike.findUnique({
      where: { postId_userId: { postId: storyId, userId: user.id } },
    });

    if (existing) {
      await db.postLike.delete({
        where: { id: existing.id },
      });
      const likesCount = await db.postLike.count({ where: { postId: storyId } });
      return NextResponse.json({ ok: true, liked: false, likesCount });
    } else {
      await db.postLike.create({
        data: { postId: storyId, userId: user.id },
      });
      const likesCount = await db.postLike.count({ where: { postId: storyId } });
      return NextResponse.json({ ok: true, liked: true, likesCount });
    }
  } catch (err: any) {
    console.error("[POST /api/mobile/stories/[id]/like]", err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(storyLikeRoutePath, storyLikeRouteContent, 'utf8');
console.log('Created:', storyLikeRoutePath);

// --- 7. Create src/app/api/mobile/stories/[id]/activity/route.ts ---
const storyActivityDir = path.join(portfolioDir, 'src/app/api/mobile/stories/[id]/activity');
if (!fs.existsSync(storyActivityDir)) fs.mkdirSync(storyActivityDir, { recursive: true });
const storyActivityRoutePath = path.join(storyActivityDir, 'route.ts');
const storyActivityRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function GET(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await resolveRequestUser(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const storyId = resolvedParams.id;

  try {
    const post = await db.post.findUnique({
      where: { id: storyId },
      include: {
        author: { select: { id: true } },
        likes: {
          include: {
            user: {
              select: {
                id: true,
                fullName: true,
                username: true,
                role: true,
                profileMediaUrl: true,
              },
            },
          },
        },
      },
    });

    if (!post) {
      return NextResponse.json({ ok: false, error: "Story not found" }, { status: 404 });
    }

    // Story owner check
    const isOwner = post.authorId === user.id;

    // Fetch unique viewers
    const views = await db.$queryRawUnsafe<Array<{ user_id: string; created_at: Date }>>(
      \`SELECT user_id, created_at FROM post_views WHERE post_id = $1 ORDER BY created_at DESC\`,
      storyId
    ).catch(() => []);

    const viewerIds = views.map(v => v.user_id);
    const viewerUsers = viewerIds.length > 0 ? await db.user.findMany({
      where: { id: { in: viewerIds } },
      select: {
        id: true,
        fullName: true,
        username: true,
        role: true,
        profileMediaUrl: true,
      },
    }) : [];

    const userMap = new Map(viewerUsers.map(u => [u.id, u]));

    const viewerList = isOwner ? views.map(v => {
      const u = userMap.get(v.user_id);
      return {
        id: v.user_id,
        name: u?.fullName || u?.username || "Colleague",
        username: u?.username,
        role: u?.role,
        avatarUrl: u?.profileMediaUrl || null,
        viewedAt: v.created_at,
      };
    }) : [];

    const likerList = (post.likes || []).map(l => ({
      id: l.user.id,
      name: l.user.fullName || l.user.username,
      username: l.user.username,
      role: l.user.role,
      avatarUrl: l.user.profileMediaUrl || null,
      likedAt: l.createdAt,
    }));

    return NextResponse.json({
      ok: true,
      storyId,
      totalViewers: views.length,
      totalLikes: post.likes.length,
      viewers: viewerList,
      likers: likerList,
      isOwner,
    });
  } catch (err: any) {
    console.error("[GET /api/mobile/stories/[id]/activity]", err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(storyActivityRoutePath, storyActivityRouteContent, 'utf8');
console.log('Created:', storyActivityRoutePath);

// --- 8. Create src/app/api/mobile/notes/[id]/like/route.ts ---
const noteLikeDir = path.join(portfolioDir, 'src/app/api/mobile/notes/[id]/like');
if (!fs.existsSync(noteLikeDir)) fs.mkdirSync(noteLikeDir, { recursive: true });
const noteLikeRoutePath = path.join(noteLikeDir, 'route.ts');
const noteLikeRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function POST(
  req: NextRequest,
  { params }: { params: any }
) {
  const user = await resolveRequestUser(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const resolvedParams = params instanceof Promise ? await params : params;
  const noteId = resolvedParams.id;

  try {
    const existing = await db.postLike.findUnique({
      where: { postId_userId: { postId: noteId, userId: user.id } },
    });

    if (existing) {
      await db.postLike.delete({ where: { id: existing.id } });
      const count = await db.postLike.count({ where: { postId: noteId } });
      return NextResponse.json({ ok: true, liked: false, likesCount: count });
    } else {
      await db.postLike.create({
        data: { postId: noteId, userId: user.id },
      });
      const count = await db.postLike.count({ where: { postId: noteId } });
      return NextResponse.json({ ok: true, liked: true, likesCount: count });
    }
  } catch (err: any) {
    console.error("[POST /api/mobile/notes/[id]/like]", err);
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(noteLikeRoutePath, noteLikeRouteContent, 'utf8');
console.log('Created:', noteLikeRoutePath);

// --- 9. Update src/app/api/mobile/notes/route.ts (include likesCount & hasLiked) ---
const notesRoutePath = path.join(portfolioDir, 'src/app/api/mobile/notes/route.ts');
const notesRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { db } from "@/lib/db";
import { validateSessionResult, getCurrentSessionResult } from "@/lib/auth";

export const runtime = "nodejs";
export const dynamic = "force-dynamic";

const NO_CACHE_HEADERS = {
  "Cache-Control": "no-store, no-cache, must-revalidate, proxy-revalidate",
  Pragma: "no-cache",
  Expires: "0",
};

async function resolveRequestUser(req: NextRequest) {
  const authHeader = req.headers.get("authorization");
  if (authHeader && authHeader.startsWith("Bearer ")) {
    const rawToken = authHeader.substring(7).trim();
    if (rawToken) {
      const res = await validateSessionResult(rawToken);
      if (res.status === "authenticated") return res.user;
    }
  }
  const cookieRes = await getCurrentSessionResult();
  if (cookieRes.status === "authenticated") return cookieRes.user;
  return null;
}

export async function GET(req: NextRequest) {
  try {
    const user = await resolveRequestUser(req);
    if (!user) {
      return NextResponse.json(
        { ok: false, error: { code: "UNAUTHORIZED", message: "Unauthorized." } },
        { status: 401, headers: NO_CACHE_HEADERS }
      );
    }

    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const rawNotes = await db.post.findMany({
      where: {
        isDeleted: false,
        createdAt: { gte: twentyFourHoursAgo },
        content: { startsWith: "[CODEXA_NOTE]" },
      },
      include: {
        author: {
          select: {
            id: true,
            fullName: true,
            username: true,
            role: true,
            profileMediaUrl: true,
            profile: {
              select: {
                displayName: true,
                mediaUrl: true,
              },
            },
          },
        },
        likes: {
          select: { userId: true },
        },
      },
      orderBy: { createdAt: "desc" },
    });

    const seenAuthors = new Set<string>();
    const notes: any[] = [];

    for (const p of rawNotes) {
      if (seenAuthors.has(p.authorId)) continue;
      seenAuthors.add(p.authorId);

      const text = p.content.replace("[CODEXA_NOTE]\\n", "").replace("[CODEXA_NOTE]", "").trim();
      const expiresAt = new Date(p.createdAt.getTime() + 24 * 60 * 60 * 1000).toISOString();
      const hasLiked = (p.likes || []).some(l => l.userId === user.id);
      const likesCount = p.likes?.length || 0;

      notes.push({
        id: p.id,
        userId: p.authorId,
        userName: p.author.fullName || p.author.profile?.displayName || p.author.username,
        username: p.author.username,
        avatarUrl: p.author.profileMediaUrl || p.author.profile?.mediaUrl || null,
        role: p.author.role,
        text,
        createdAt: p.createdAt.toISOString(),
        expiresAt,
        isSelf: p.authorId === user.id,
        hasLiked,
        likesCount,
      });
    }

    return NextResponse.json({ ok: true, notes }, { headers: NO_CACHE_HEADERS });
  } catch (err: any) {
    console.error("[GET /api/mobile/notes error]", err);
    return NextResponse.json(
      { ok: false, error: { code: "SERVER_ERROR", message: "Failed to load notes." } },
      { status: 500, headers: NO_CACHE_HEADERS }
    );
  }
}

export async function POST(req: NextRequest) {
  try {
    const user = await resolveRequestUser(req);
    if (!user) {
      return NextResponse.json(
        { ok: false, error: { code: "UNAUTHORIZED", message: "Unauthorized." } },
        { status: 401, headers: NO_CACHE_HEADERS }
      );
    }

    const body = await req.json();
    let text = (body.text || "").trim();

    if (!text) {
      return NextResponse.json(
        { ok: false, error: { code: "BAD_REQUEST", message: "Note text cannot be empty." } },
        { status: 400, headers: NO_CACHE_HEADERS }
      );
    }

    if (text.length > 60) {
      text = text.substring(0, 60);
    }

    const twentyFourHoursAgo = new Date(Date.now() - 24 * 60 * 60 * 1000);
    await db.post.updateMany({
      where: {
        authorId: user.id,
        content: { startsWith: "[CODEXA_NOTE]" },
        createdAt: { gte: twentyFourHoursAgo },
        isDeleted: false,
      },
      data: { isDeleted: true },
    });

    const created = await db.post.create({
      data: {
        authorId: user.id,
        content: \`[CODEXA_NOTE]\\n\${text}\`,
      },
    });

    return NextResponse.json({
      ok: true,
      note: {
        id: created.id,
        userId: created.authorId,
        userName: user.displayName || user.username,
        username: user.username,
        avatarUrl: user.mediaUrl || null,
        role: user.role,
        text,
        createdAt: created.createdAt.toISOString(),
        expiresAt: new Date(created.createdAt.getTime() + 24 * 60 * 60 * 1000).toISOString(),
        isSelf: true,
        hasLiked: false,
        likesCount: 0,
      },
    }, { headers: NO_CACHE_HEADERS });
  } catch (err: any) {
    console.error("[POST /api/mobile/notes error]", err);
    return NextResponse.json(
      { ok: false, error: { code: "SERVER_ERROR", message: "Failed to publish note." } },
      { status: 500, headers: NO_CACHE_HEADERS }
    );
  }
}
`;
fs.writeFileSync(notesRoutePath, notesRouteContent, 'utf8');
console.log('Updated:', notesRoutePath);

console.log('ALL BACKEND FEATURES SUCCESSFULLY UPDATED!');
