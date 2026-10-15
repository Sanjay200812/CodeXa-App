const fs = require('fs');
const path = require('path');

const portfolioDir = 'G:/AntiGravity IDE/CodeXa/codexa-portfolio';

// 1. Update src/app/api/chat/conversations/route.ts
const convRoutePath = path.join(portfolioDir, 'src/app/api/chat/conversations/route.ts');
const convRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
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
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

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
        let otherUserId = (conv.conversation_members || []).find(
          (m: any) => m.core_user_id !== user.id
        )?.core_user_id;

        if (!otherUserId && conv.direct_pair_key) {
          const parts = String(conv.direct_pair_key).split("::");
          otherUserId = parts.find((p: string) => p !== user.id);
        }

        if (otherUserId) {
          const userRecord = await prisma.user.findUnique({
            where: { id: otherUserId },
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
          });

          const displayName =
            userRecord?.fullName ||
            userRecord?.profile?.displayName ||
            userRecord?.username ||
            "CodeXa Colleague";

          const avatarUrl =
            userRecord?.profileMediaUrl ||
            userRecord?.profile?.mediaUrl ||
            null;

          const recipientUser = {
            id: otherUserId,
            fullName: displayName,
            displayName,
            name: displayName,
            username: userRecord?.username || "colleague",
            role: userRecord?.role || "MEMBER",
            profileMediaUrl: avatarUrl,
            avatarUrl,
          };

          return {
            ...conv,
            name: displayName,
            title: displayName,
            avatarUrl,
            recipientUser,
            peer: recipientUser,
            otherParticipantCoreUserId: otherUserId,
            otherParticipantDisplayName: displayName,
            otherParticipantUsername: userRecord?.username || "colleague",
            otherParticipantAvatar: avatarUrl,
            otherParticipantRole: userRecord?.role || "MEMBER",
          };
        }
      }

      // Group or fallback
      const groupTitle = conv.title || conv.name || "Team Group";
      const groupIcon =
        conv.metadata?.iconUrl ||
        conv.metadata?.avatarUrl ||
        conv.icon_url ||
        conv.avatar_url ||
        null;

      return {
        ...conv,
        name: groupTitle,
        title: groupTitle,
        avatarUrl: groupIcon,
      };
    })
  );

  return NextResponse.json({ ok: true, conversations: conversationsWithDetails });
}

export async function POST(req: NextRequest) {
  const user = await getAuthUserFromRequest(req);
  if (!user) {
    return NextResponse.json({ ok: false, error: "Unauthorized" }, { status: 401 });
  }

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
        select: {
          id: true,
          role: true,
          fullName: true,
          username: true,
          isActive: true,
          profileMediaUrl: true,
          profile: {
            select: { displayName: true, mediaUrl: true }
          }
        },
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

      const displayName =
        recipient.fullName ||
        recipient.profile?.displayName ||
        recipient.username ||
        "CodeXa Colleague";

      const avatarUrl =
        recipient.profileMediaUrl ||
        recipient.profile?.mediaUrl ||
        null;

      const recipientDTO = {
        id: recipient.id,
        fullName: displayName,
        displayName,
        name: displayName,
        username: recipient.username,
        role: recipient.role,
        profileMediaUrl: avatarUrl,
        avatarUrl,
      };

      return NextResponse.json({
        ok: true,
        conversation: {
          ...conversation,
          type: "DIRECT",
          name: displayName,
          title: displayName,
          avatarUrl,
          recipientUser: recipientDTO,
          peer: recipientDTO,
          otherParticipantCoreUserId: recipient.id,
          otherParticipantDisplayName: displayName,
          otherParticipantUsername: recipient.username,
          otherParticipantAvatar: avatarUrl,
          otherParticipantRole: recipient.role,
        },
      });
    } else {
      // Group conversation
      const groupTitle = title || "New Group";
      const { data: newConv, error: convErr } = await chatSupabaseAdmin
        .from("conversations")
        .insert({
          type: "GROUP",
          title: groupTitle,
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

      return NextResponse.json({
        ok: true,
        conversation: {
          ...newConv,
          name: groupTitle,
          title: groupTitle,
        },
      });
    }
  } catch (err: any) {
    return NextResponse.json({ ok: false, error: err.message }, { status: 500 });
  }
}
`;
fs.writeFileSync(convRoutePath, convRouteContent, 'utf8');
console.log('Updated:', convRoutePath);

// 2. Update src/app/api/chat/conversations/[id]/route.ts
const convIdRoutePath = path.join(portfolioDir, 'src/app/api/chat/conversations/[id]/route.ts');
const convIdRouteContent = `import { NextRequest, NextResponse } from "next/server";
import { getAuthUserFromRequest } from "@/lib/auth";
import { prisma } from "@/lib/prisma";
import { chatSupabaseAdmin, isChatConfigured } from "@/lib/supabase/chat-admin";
import { saveMediaUpload } from "@/lib/media-storage";
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
    select: {
      id: true,
      fullName: true,
      username: true,
      role: true,
      profileMediaUrl: true,
      profile: {
        select: { displayName: true, mediaUrl: true }
      }
    },
  });

  let displayName = conversation.title || conversation.name || (conversation.type === "GROUP" ? "Team Group" : "Chat");
  let avatarUrl = conversation.metadata?.iconUrl || conversation.metadata?.avatarUrl || null;
  let recipientUser = null;
  let otherParticipantRole = "MEMBER";

  if (conversation.type === "DIRECT") {
    let otherUserId = (conversation.conversation_members || []).find(
      (m: any) => m.core_user_id !== user.id
    )?.core_user_id;

    if (!otherUserId && conversation.direct_pair_key) {
      const parts = String(conversation.direct_pair_key).split("::");
      otherUserId = parts.find((p: string) => p !== user.id);
    }

    const otherUser = coreUsers.find(u => u.id === otherUserId);
    if (otherUser) {
      displayName = otherUser.fullName || otherUser.profile?.displayName || otherUser.username || "CodeXa Colleague";
      avatarUrl = otherUser.profileMediaUrl || otherUser.profile?.mediaUrl || null;
      otherParticipantRole = otherUser.role;
      recipientUser = {
        id: otherUser.id,
        fullName: displayName,
        displayName,
        name: displayName,
        username: otherUser.username,
        role: otherUser.role,
        profileMediaUrl: avatarUrl,
        avatarUrl,
      };
    }
  }

  return NextResponse.json({
    ok: true,
    conversation: {
      ...conversation,
      name: displayName,
      title: displayName,
      avatarUrl,
      recipientUser,
      peer: recipientUser,
      otherParticipantDisplayName: displayName,
      otherParticipantAvatar: avatarUrl,
      otherParticipantRole,
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

  // Group avatar validation: only group conversations have group icons
  if (conv.type !== "GROUP") {
    return NextResponse.json({
      ok: false,
      error: { code: "NOT_A_GROUP", message: "Only group conversations can have group settings or icons." },
    }, { status: 400 });
  }

  // Permission check for group modifications
  const isOwnerOrAdmin =
    member.role === "OWNER" ||
    member.role === "ADMIN" ||
    ["FOUNDER", "CO_FOUNDER", "CEO", "CTO", "HR", "COO", "OWNER", "ADMIN"].includes(user.role);

  if (!isOwnerOrAdmin) {
    return NextResponse.json({
      ok: false,
      error: { code: "FORBIDDEN", message: "Only group administrators or leadership can update group details." },
    }, { status: 403 });
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
      const filename = \`group_\${conversationId}_\${Date.now()}\${ext}\`;
      const uploadRes = await saveMediaUpload("group-icons", buffer, filename, file.type || "image/jpeg", conversationId);
      if (!uploadRes.publicUrl) {
        return NextResponse.json({
          ok: false,
          error: { code: "GROUP_ICON_UPDATE_FAILED", message: "Failed to upload group icon to cloud storage." },
        }, { status: 500 });
      }
      iconUrl = uploadRes.publicUrl;
    }
  } else {
    const body = await req.json().catch(() => ({}));
    title = body.title;
    iconUrl = body.iconUrl || body.avatarUrl;

    if (body.base64) {
      const cleanBase64 = body.base64.replace(/^data:[^;]+;base64,/, "");
      const buffer = Buffer.from(cleanBase64, "base64");
      const filename = \`group_\${conversationId}_\${Date.now()}.jpg\`;
      const uploadRes = await saveMediaUpload("group-icons", buffer, filename, "image/jpeg", conversationId);
      if (!uploadRes.publicUrl) {
        return NextResponse.json({
          ok: false,
          error: { code: "GROUP_ICON_UPDATE_FAILED", message: "Failed to upload group icon to cloud storage." },
        }, { status: 500 });
      }
      iconUrl = uploadRes.publicUrl;
    }
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
fs.writeFileSync(convIdRoutePath, convIdRouteContent, 'utf8');
console.log('Updated:', convIdRoutePath);
