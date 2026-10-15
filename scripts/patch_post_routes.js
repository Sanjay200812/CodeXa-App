const fs = require('fs');
const path = require('path');

const mobilePostsPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/mobile/posts/route.ts');
let mobileContent = fs.readFileSync(mobilePostsPath, 'utf8');
if (!mobileContent.includes('NOT: { content: { startsWith: "[CODEXA_STORY" } }')) {
  mobileContent = mobileContent.replace(
    'where: { isDeleted: false },',
    'where: { isDeleted: false, NOT: { content: { startsWith: "[CODEXA_STORY" } } },'
  );
  fs.writeFileSync(mobilePostsPath, mobileContent, 'utf8');
  console.log('Successfully filtered out stories in mobile/posts/route.ts');
}

const feedPostsPath = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/src/app/api/feed/posts/route.ts');
if (fs.existsSync(feedPostsPath)) {
  let feedContent = fs.readFileSync(feedPostsPath, 'utf8');
  if (!feedContent.includes('NOT: { content: { startsWith: "[CODEXA_STORY" } }')) {
    feedContent = feedContent.replace(
      'where: { isDeleted: false },',
      'where: { isDeleted: false, NOT: { content: { startsWith: "[CODEXA_STORY" } } },'
    );
    fs.writeFileSync(feedPostsPath, feedContent, 'utf8');
    console.log('Successfully filtered out stories in feed/posts/route.ts');
  }
}
