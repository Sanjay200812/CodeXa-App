const fs = require('fs');
const path = require('path');

const baseChatApiDir = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/chat');

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

// 1. /api/chat/token/route.ts
ensureDir(path.join(baseChatApiDir, 'token'));
const tokenRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { signChatToken, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function GET(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  const token = signChatToken(user.id);
  const chatUrl = process.env.CHAT_SUPABASE_URL || process.env.NEXT_PUBLIC_CHAT_SUPABASE_URL || "";
  const publishableKey = process.env.CHAT_SUPABASE_PUBLISHABLE_KEY || process.env.NEXT_PUBLIC_CHAT_SUPABASE_PUBLISHABLE_KEY || "";

  return NextResponse.json({
    ok: true,
    token,
    coreUserId: user.id,
    expiresIn: 3600,
    chatConfig: {
      url: chatUrl,
      publishableKey,
      isConfigured: isChatConfigured(),
    },
  });
}

export async function POST(req: NextRequest) {
  return GET(req);
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'token', 'route.ts'), tokenRoute, 'utf8');

// 2. /api/chat/conversations/route.ts
ensureDir(path.join(baseChatApiDir, 'conversations'));
const conversationsRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import {
  getUserConversations,
  getOrCreateDirectConversation,
  chatSupabaseAdmin,
  isChatConfigured
} from "@/lib/supabase/chat-admin";

function canInitiateDirectMessage(senderRole: string, recipientRole: string): boolean {
  if (senderRole === "FOUNDER" || senderRole === "CEO" || senderRole === "CTO") return true;
  if (senderRole === "INTERN" && (recipientRole === "FOUNDER" || recipientRole === "CEO")) {
    return false; // Direct message to Founder/CEO restricted for interns
  }
  return true;
}

export async function GET(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: true, conversations: [] });
  }

  const { data, error } = await getUserConversations(user.id);
  if (error) {
    return NextResponse.json({ ok: false, error }, { status: 500 });
  }

  // Populate recipient metadata from Core DB for direct chats
  const conversationsWithDetails = await Promise.all(
    (data || []).map(async (conv: any) => {
      if (conv.type === "DIRECT") {
        const otherMember = (conv.conversation_members || []).find(
          (m: any) => m.core_user_id !== user.id
        );
        if (otherMember) {
          const userRecord = await prisma.user.findUnique({
            where: { id: otherMember.core_user_id },
            select: { id: true, fullName: true, username: true, role: true, profileMediaUrl: true },
          });
          return {
            ...conv,
            recipientUser: userRecord || { id: otherMember.core_user_id, fullName: "CodeXa Colleague", username: "colleague" },
          };
        }
      }
      return conv;
    })
  );

  return NextResponse.json({ ok: true, conversations: conversationsWithDetails });
}

export async function POST(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  try {
    const body = await req.json();
    const { type = "DIRECT", targetUserId, title, memberIds } = body;

    if (!isChatConfigured() || !chatSupabaseAdmin) {
      return NextResponse.json({ ok: false, error: "Chat infrastructure is not configured" }, { status: 503 });
    }

    if (type === "DIRECT") {
      if (!targetUserId) {
        return NextResponse.json({ ok: false, error: "targetUserId is required for direct conversation" }, { status: 400 });
      }

      // Check communication permission
      const recipient = await prisma.user.findUnique({
        where: { id: targetUserId },
        select: { id: true, role: true, fullName: true, username: true, isActive: true },
      });

      if (!recipient) {
        return NextResponse.json({ ok: false, error: "Target user not found" }, { status: 404 });
      }

      if (!recipient.isActive) {
        return NextResponse.json({ ok: false, error: "Target user is disabled" }, { status: 400 });
      }

      if (!canInitiateDirectMessage(user.role, recipient.role)) {
        return NextResponse.json({
          ok: false,
          error: "Direct communication with this role is restricted by CodeXa workspace policy.",
        }, { status: 403 });
      }

      // Check block status
      const { data: block } = await chatSupabaseAdmin
        .from("chat_blocks")
        .select("id")
        .or(\`and(blocker_core_user_id.eq.\${targetUserId},blocked_core_user_id.eq.\${user.id}),and(blocker_core_user_id.eq.\${user.id},blocked_core_user_id.eq.\${targetUserId})\`)
        .maybeSingle();

      if (block) {
        return NextResponse.json({ ok: false, error: "Cannot start conversation with this user." }, { status: 403 });
      }

      const { data: conversation, error } = await getOrCreateDirectConversation(
        user.id,
        targetUserId
      );

      if (error) {
        return NextResponse.json({ ok: false, error }, { status: 500 });
      }

      return NextResponse.json({ ok: true, conversation });
    } else {
      // Group conversation
      const { data: newConv, error: convErr } = await chatSupabaseAdmin
        .from("conversations")
        .insert({
          type: "GROUP",
          title: title || "New Group",
          created_by_core_user_id: user.id,
        })
        .select()
        .single();

      if (convErr || !newConv) {
        return NextResponse.json({ ok: false, error: convErr?.message || "Failed to create group" }, { status: 500 });
      }

      const allMembers = Array.from(new Set([user.id, ...(memberIds || [])]));
      const memberRows = allMembers.map((mId: string) => ({
        conversation_id: newConv.id,
        core_user_id: mId,
        member_role: mId === user.id ? "OWNER" : "MEMBER",
      }));

      await chatSupabaseAdmin.from("conversation_members").insert(memberRows);

      return NextResponse.json({ ok: true, conversation: newConv });
    }
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'conversations', 'route.ts'), conversationsRoute, 'utf8');

// 3. /api/chat/conversations/[id]/route.ts
ensureDir(path.join(baseChatApiDir, 'conversations', '[id]'));
const conversationDetailRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat not configured" }, { status: 503 });
  }

  const conversationId = params.id;

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
`;
fs.writeFileSync(path.join(baseChatApiDir, 'conversations', '[id]', 'route.ts'), conversationDetailRoute, 'utf8');

// 4. /api/chat/conversations/[id]/messages/route.ts
ensureDir(path.join(baseChatApiDir, 'conversations', '[id]', 'messages'));
const conversationMessagesRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import {
  chatSupabaseAdmin,
  sendChatMessage,
  isChatConfigured
} from "@/lib/supabase/chat-admin";

export async function GET(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: true, messages: [] });
  }

  const conversationId = params.id;
  const { searchParams } = new URL(req.url);
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

  return NextResponse.json({
    ok: true,
    messages: (messages || []).reverse(),
  });
}

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat service unavailable" }, { status: 503 });
  }

  try {
    const body = await req.json();
    const { text, clientMessageId, messageType = "TEXT", replyToMessageId } = body;

    if (!clientMessageId) {
      return NextResponse.json({ ok: false, error: "clientMessageId is required" }, { status: 400 });
    }

    if (!text && messageType === "TEXT") {
      return NextResponse.json({ ok: false, error: "Message text cannot be empty" }, { status: 400 });
    }

    const result = await sendChatMessage({
      conversationId: params.id,
      senderCoreUserId: user.id,
      clientMessageId,
      text,
      messageType,
      replyToMessageId,
    });

    if (result.error) {
      return NextResponse.json({ ok: false, error: result.error }, { status: 400 });
    }

    // Trigger Core notification if this is a newly inserted message (not duplicate retry)
    if (!result.isDuplicate && result.data) {
      const { data: members } = await chatSupabaseAdmin
        .from("conversation_members")
        .select("core_user_id, muted")
        .eq("conversation_id", params.id)
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
                  title: \`Message from \${user.name}\`,
                  message: (text || "Sent an attachment").slice(0, 120),
                  link: \`/messages/\${params.id}\`,
                },
              });
            } catch (_) {}
          }
        }
      }
    }

    return NextResponse.json({
      ok: true,
      message: result.data,
      isDuplicate: result.isDuplicate,
    });
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'conversations', '[id]', 'messages', 'route.ts'), conversationMessagesRoute, 'utf8');

// 5. /api/chat/messages/[id]/read/route.ts
ensureDir(path.join(baseChatApiDir, 'messages', '[id]', 'read'));
const messageReadRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: true });
  }

  await chatSupabaseAdmin
    .from("message_reads")
    .upsert({
      message_id: params.id,
      core_user_id: user.id,
      read_at: new Date().toISOString(),
    }, { onConflict: "message_id,core_user_id" });

  return NextResponse.json({ ok: true });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'messages', '[id]', 'read', 'route.ts'), messageReadRoute, 'utf8');

// 6. /api/chat/messages/[id]/reactions/route.ts
ensureDir(path.join(baseChatApiDir, 'messages', '[id]', 'reactions'));
const reactionsRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function POST(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const { reaction } = await req.json();
  if (!reaction) {
    return NextResponse.json({ ok: false, error: "Reaction required" }, { status: 400 });
  }

  const { data, error } = await chatSupabaseAdmin
    .from("message_reactions")
    .upsert({
      message_id: params.id,
      core_user_id: user.id,
      reaction,
    }, { onConflict: "message_id,core_user_id,reaction" })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, reaction: data });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'messages', '[id]', 'reactions', 'route.ts'), reactionsRoute, 'utf8');

// 7. /api/chat/messages/[id]/route.ts
ensureDir(path.join(baseChatApiDir, 'messages', '[id]'));
const messageDetailRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function DELETE(
  req: NextRequest,
  { params }: { params: { id: string } }
) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const { data, error } = await chatSupabaseAdmin
    .from("messages")
    .update({
      deleted_at: new Date().toISOString(),
      text: "[Message deleted]",
    })
    .eq("id", params.id)
    .eq("sender_core_user_id", user.id)
    .select()
    .single();

  if (error || !data) {
    return NextResponse.json({ ok: false, error: "Could not delete message or not permitted" }, { status: 403 });
  }

  return NextResponse.json({ ok: true, deleted: true });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'messages', '[id]', 'route.ts'), messageDetailRoute, 'utf8');

// 8. /api/chat/reports/route.ts
ensureDir(path.join(baseChatApiDir, 'reports'));
const reportsRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function POST(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const { conversationId, messageId, reason, details } = await req.json();
  if (!reason) {
    return NextResponse.json({ ok: false, error: "Reason is required" }, { status: 400 });
  }

  const { data, error } = await chatSupabaseAdmin
    .from("chat_reports")
    .insert({
      reporter_core_user_id: user.id,
      conversation_id: conversationId || null,
      message_id: messageId || null,
      reason,
      details: details || null,
      status: "OPEN",
    })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, report: data });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'reports', 'route.ts'), reportsRoute, 'utf8');

// 9. /api/chat/blocks/route.ts
ensureDir(path.join(baseChatApiDir, 'blocks'));
const blocksRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function POST(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const { targetUserId } = await req.json();
  if (!targetUserId) {
    return NextResponse.json({ ok: false, error: "targetUserId required" }, { status: 400 });
  }

  const { data, error } = await chatSupabaseAdmin
    .from("chat_blocks")
    .upsert({
      blocker_core_user_id: user.id,
      blocked_core_user_id: targetUserId,
    }, { onConflict: "blocker_core_user_id,blocked_core_user_id" })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, block: data });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'blocks', 'route.ts'), blocksRoute, 'utf8');

// 10. /api/chat/mutes/route.ts
ensureDir(path.join(baseChatApiDir, 'mutes'));
const mutesRoute = `import { NextRequest, NextResponse } from "next/server";
import { getCurrentSessionResult } from "@/lib/auth";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";

export async function POST(req: NextRequest) {
  const sessionResult = await getCurrentSessionResult();
  if (sessionResult.status !== "authenticated") {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

  const user = sessionResult.user;

  if (!isChatConfigured() || !chatSupabaseAdmin) {
    return NextResponse.json({ ok: false, error: "Chat unavailable" }, { status: 503 });
  }

  const { conversationId, mutedUntil } = await req.json();
  if (!conversationId) {
    return NextResponse.json({ ok: false, error: "conversationId required" }, { status: 400 });
  }

  const { data, error } = await chatSupabaseAdmin
    .from("chat_mutes")
    .upsert({
      core_user_id: user.id,
      conversation_id: conversationId,
      muted_until: mutedUntil || null,
    }, { onConflict: "core_user_id,conversation_id" })
    .select()
    .single();

  if (error) {
    return NextResponse.json({ ok: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ ok: true, mute: data });
}
`;
fs.writeFileSync(path.join(baseChatApiDir, 'mutes', 'route.ts'), mutesRoute, 'utf8');

console.log('All Chat API routes generated successfully in:', baseChatApiDir);
