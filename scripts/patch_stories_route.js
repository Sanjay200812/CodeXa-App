const fs = require('fs');
const filePath = 'G:/AntiGravity IDE/CodeXa/codexa-portfolio/src/app/api/mobile/stories/route.ts';
let content = fs.readFileSync(filePath, 'utf8');

content = content.replace(
  'if (contentType.includes("multipart/form-data")) {\n      const formData = await req.formData();',
  'let formData: FormData | null = null;\n    let body: any = null;\n\n    if (contentType.includes("multipart/form-data")) {\n      formData = await req.formData();'
);

content = content.replace(
  '} else {\n      const body = await req.json().catch(() => ({}));',
  '} else {\n      body = await req.json().catch(() => ({}));'
);

content = content.replace(
  'const mentionsRaw = (formData.get("mentions") as string) || "";',
  'const mentionsRaw = formData ? ((formData.get("mentions") as string) || "") : "";'
);

content = content.replace(
  'const body = await req.json().catch(() => ({}));\n      if (Array.isArray(body.mentions)) {',
  'if (body && Array.isArray(body.mentions)) {'
);

fs.writeFileSync(filePath, content, 'utf8');
console.log('Fixed formData in stories/route.ts successfully');
