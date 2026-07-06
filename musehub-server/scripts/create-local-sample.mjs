import fs from 'node:fs';
import path from 'node:path';

const musicDir = process.env.MUSIC_DIR ?? './music';
fs.mkdirSync(musicDir, { recursive: true });

const samplePath = path.join(musicDir, 'Coldplay - Yellow.mp3');
if (!fs.existsSync(samplePath)) {
  fs.writeFileSync(samplePath, 'MuseHub Server V0 local sample audio bytes\n');
}

console.log(`Created sample local track: ${samplePath}`);
