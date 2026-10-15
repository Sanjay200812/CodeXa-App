const fs = require('fs');
const path = require('path');

const file = path.resolve(__dirname, '../../CodeXa/codexa-portfolio/.env');
if (fs.existsSync(file)) {
  let content = fs.readFileSync(file, 'utf8');
  
  const clientEmail = 'firebase-adminsdk-fbsvc@codxa-agency.iam.gserviceaccount.com';
  const privateKey = '-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQChVPS64V3KSzrB\\nz+HZIs2sTr249dCe6Wf57QmOEXELc5Awy3gMbYSHT2eoOCSurq1XhIK0pICcWSPg\\nwBt/640+/W1e0T3mxzQX0geLiVlREyojoNBY5OxkZfWQDI7wu3xf/ObnDn6zEo3d\\nsXeGnLZez6T71mNeTvroIj6Ue3P/n36IZR9zCEGnRlKTBUpf07T+rxTZpsi2pJHT\\nI8+whqA9dzOzrL+eUe36AUvZWwCbuBCeVjUYV5fgpxbmgTeKbcC5OVdjb3+DuTkC\\nFa/tNZiMoT93ih6T7H/2TxaJ7h9Z0bjNt264OK8T/VcY+N4aCABxN/Vo8bHFHoR8\\nZTJbxJmZAgMBAAECggEAFCQUzHrjuGRVcMpI3hCKAEOxTFTF53zoqes1iOq1A/K4\\nstrIATcv9yuK25WswLEWe2lT3wT1eG9pev7IwBrSXqWJYK+7LGM8peem4Pzz7Vr4\\n5QtHz30+5NbUxhfHRZcGcz5RvlFRMH51vxJPg3rvip0eMgGFFMpD6TSTPvq9k9Et\\nFmKVfQByg/vUypVQVOxyuBWdhLTpQuoSLfd3iiR1v/I4RC52Q/xtiDGEwfD+Z9gv\\nUILG75oG/xE8trYHin7V2AbV9ChCEGPWldUQK12xc247UhSTXJ+0VDTIhLhYNXxd\\ngAUjFggdWX7PXX2tyvNXBqBcQTEAj1yHBAJaD76ywQKBgQDSsZkRL4zdGVuKvS3k\\nJ14W2m1wvflN7nsNyaKAEPp5HG3IxbmPWrm2MsBvagm9wcfGzx10KKYKGlubXzQE\\nzDJGe0xQU65/quKEJp77BGPu+sojeekNanCP8Df4HzZuGCF+HEnY5ttOob4Sn/7k\\nLNXLoDWQs9Q6zYsEyvSN3yMJYQKBgQDEBg3SV5paVTHWZTB5brbB3XBIOaumc4vA\\nwKbNlQTIoYTQwVsT9vIebinrenTRdunYeVqELTOMoSu5G3C0GXew0IKLHBtC/Skf\\ndD504OA3smAR2eJykRaX8JdVsGUbXwkJQIJRnCq7LG2gcAbBwCq4m34pTaxGszTm\\nYAmg7LdjOQKBgQCF8eIdyt0Cstw/l4VVRrHKVZK92ghkQvh4C3gDcsfJtwkUWp9d\\nQ5BNBHbSXddTi542BfXzouPsCFW0sRGg+y/7HuelKY4GG91lpifr7R6bD1TyuM4w\\neTqWR2FNnIo985lXUySfgCRsGOd9b7nb1aUVjwR+udRyjbmTknNmvjTIAQKBgQCB\\nuvP4ymtn70w9dNig9SnUoeXGlwxH696I4bdDBaWV1nec5OqPCvbwNr5djryzR/y5\\nfI7wPS4JmzzhlAyB1P0GsuhCgoZ0TjGiFH+lQJKDqfS0u7uHUQhf5CVz23r+o2XK\\njrvwoOcS2vNuo9WE8tYTOS1Ezpf+bmnLMbINo7w22QKBgA+xUBWWtxxhW0LU7Dvb\\nd3WqOL4vGLy3vrA6NLFUaJiCyPUCdPR0dMgr4YBEqBlKZpmH1JkPpLyLdBMMME/l\\nxVIQRB9ahwp2+NHS2Q93mHl1/aJtlMei8NRKUUsHXLzLxf39M0XwxbvQH0lqT2xM\\nT+kkJzR9kPQHxqiaYv/AiGui\\n-----END PRIVATE KEY-----\\n';

  content = content.replace(/FIREBASE_CLIENT_EMAIL=".*"/, `FIREBASE_CLIENT_EMAIL="${clientEmail}"`);
  content = content.replace(/FIREBASE_PRIVATE_KEY=".*"/, `FIREBASE_PRIVATE_KEY="${privateKey}"`);
  
  fs.writeFileSync(file, content, 'utf8');
  console.log('Successfully updated Firebase Admin credentials in backend .env');
}
