const fs = require('fs');
const path = require('path');

const targetPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/lib/supabase.ts');
let content = fs.readFileSync(targetPath, 'utf8');

content = content.replace(
  `        file_size_limit: 10485760, // 10 MB\n        allowed_mime_types: ["image/jpeg", "image/png", "image/webp", "image/gif"],`,
  `        file_size_limit: 52428800, // 50 MB (supports videos & media)\n        allowed_mime_types: ["image/jpeg", "image/png", "image/webp", "image/gif", "video/mp4", "video/webm", "video/quicktime", "video/3gpp", "video/x-matroska", "application/pdf"],`
);

fs.writeFileSync(targetPath, content, 'utf8');
console.log('Successfully updated supabaseEnsureBucket in supabase.ts');
