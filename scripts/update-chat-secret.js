const fs = require('fs');
const path = require('path');

const file = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
if (fs.existsSync(file)) {
  let content = fs.readFileSync(file, 'utf8');
  content = content.replace(
    'CHAT_JWT_SECRET="your_custom_jwt_signing_secret_min_32_characters_here"',
    'CHAT_JWT_SECRET="7eb20d1468d465e639ed3e3e5a69ecc5676aa0c03ac21592eaa88a0f10aae44b"'
  );
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully updated CHAT_JWT_SECRET in backend .env');
}
