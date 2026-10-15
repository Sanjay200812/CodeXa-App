const fs = require('fs');
const path = require('path');

const storiesRoutePath = path.resolve(__dirname, '..', '..', 'CodeXa', 'codexa-portfolio', 'src', 'app', 'api', 'mobile', 'stories', 'route.ts');
let content = fs.readFileSync(storiesRoutePath, 'utf8');

// Check if CREW_ROLES is defined
if (!content.includes('CREW_ROLES')) {
  const crewRolesDef = `
const CREW_ROLES = [
  "FOUNDER",
  "CO_FOUNDER",
  "CEO",
  "CTO",
  "COO",
  "HR",
  "CORE_TEAM",
  "TEAM_MEMBER",
  "EMPLOYEE",
  "INTERN",
  "ADMIN",
];
`;
  content = content.replace('const NO_CACHE_HEADERS = {', crewRolesDef + '\nconst NO_CACHE_HEADERS = {');
}

// In POST function, add crew mentions validation
const oldValidationAnchor = 'const validTypes = ["TEXT", "IMAGE", "VIDEO", "PROJECT_UPDATE", "ANNOUNCEMENT", "MILESTONE"];';
const newValidationCode = `
    // Parse mentions (either explicitly passed or extracted from @usernames in content)
    let mentionedUserIds: string[] = [];
    if (contentType.includes("multipart/form-data")) {
      const mentionsRaw = (formData.get("mentions") as string) || "";
      if (mentionsRaw) {
        try {
          const parsed = JSON.parse(mentionsRaw);
          if (Array.isArray(parsed)) mentionedUserIds = parsed;
        } catch (_) {
          mentionedUserIds = mentionsRaw.split(",").map(m => m.trim()).filter(Boolean);
        }
      }
    } else {
      const body = await req.json().catch(() => ({}));
      if (Array.isArray(body.mentions)) {
        mentionedUserIds = body.mentions;
      }
    }

    // Extract @usernames from text content
    const usernameMatches = (content.match(/@([a-zA-Z0-9_\\.]+)/g) || []).map((m) => m.slice(1).toLowerCase());

    // 15 & 16. Validate mentions - Crew Members Only
    if (mentionedUserIds.length > 0 || usernameMatches.length > 0) {
      const usersToCheck = await db.user.findMany({
        where: {
          OR: [
            ...(mentionedUserIds.length > 0 ? [{ id: { in: mentionedUserIds } }] : []),
            ...(usernameMatches.length > 0 ? [{ username: { in: usernameMatches } }] : []),
          ],
        },
        select: { id: true, username: true, role: true, isActive: true },
      });

      // Ensure every mentioned user exists and is an active Crew member
      for (const mUser of usersToCheck) {
        if (!mUser.isActive || !CREW_ROLES.includes(mUser.role)) {
          return NextResponse.json({
            ok: false,
            error: {
              code: "STORY_MENTION_NOT_ALLOWED",
              message: \`User @\${mUser.username} is not an authorized CodeXa Crew member.\`,
            },
          }, { status: 400, headers: NO_CACHE_HEADERS });
        }
      }
    }

    const validTypes = ["TEXT", "IMAGE", "VIDEO", "PROJECT_UPDATE", "ANNOUNCEMENT", "MILESTONE"];`;

if (content.includes(oldValidationAnchor) && !content.includes('STORY_MENTION_NOT_ALLOWED')) {
  content = content.replace(oldValidationAnchor, newValidationCode);
  fs.writeFileSync(storiesRoutePath, content, 'utf8');
  console.log('Successfully updated stories/route.ts with crew mentions validation!');
} else {
  console.log('Anchor already updated or not found.');
}
