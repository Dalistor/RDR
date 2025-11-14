/**
 * Script para gerar ícones do app em todos os tamanhos necessários
 *
 * Coloque seu logo original (preferencialmente 1024x1024px) em:
 * - assets/logo/logo.png (ou logo.jpg)
 *
 * Execute: npm run generate-icons
 */

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';
import { dirname } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Tamanhos necessários para Android (em pixels)
const androidSizes = {
  'mipmap-mdpi': 48,
  'mipmap-hdpi': 72,
  'mipmap-xhdpi': 96,
  'mipmap-xxhdpi': 144,
  'mipmap-xxxhdpi': 192
};

// Tamanhos para foreground (adaptive icon)
const foregroundSizes = {
  'mipmap-mdpi': 108,
  'mipmap-hdpi': 162,
  'mipmap-xhdpi': 216,
  'mipmap-xxhdpi': 324,
  'mipmap-xxxhdpi': 432
};

async function generateIcons() {
  try {
    // Verifica se sharp está instalado
    let sharp;
    try {
      sharp = (await import('sharp')).default;
    } catch (e) {
      console.error('❌ Erro: A biblioteca "sharp" não está instalada.');
      console.log('📦 Por favor, instale manualmente: npm install --save-dev sharp');
      process.exit(1);
    }

    const logoDir = path.join(__dirname, '..', 'assets', 'logo');
    const androidResDir = path.join(__dirname, '..', 'src-capacitor', 'android', 'app', 'src', 'main', 'res');

    // Procura o arquivo de logo
    const logoFiles = ['logo.png', 'logo.jpg', 'logo.jpeg', 'logo.webp'];
    let logoPath = null;

    for (const file of logoFiles) {
      const testPath = path.join(logoDir, file);
      if (fs.existsSync(testPath)) {
        logoPath = testPath;
        break;
      }
    }

    if (!logoPath) {
      console.error('❌ Erro: Logo não encontrado!');
      console.log('📁 Coloque seu logo em: assets/logo/logo.png (ou .jpg/.jpeg/.webp)');
      console.log('💡 O logo deve ser quadrado, preferencialmente 1024x1024px ou maior');
      process.exit(1);
    }

    console.log(`✅ Logo encontrado: ${logoPath}`);
    console.log('🔄 Gerando ícones...\n');

    // Carrega a imagem
    const image = sharp(logoPath);
    const metadata = await image.metadata();
    console.log(`📐 Dimensões do logo: ${metadata.width}x${metadata.height}px\n`);

    // Gera ícones normais (ic_launcher.png)
    for (const [folder, size] of Object.entries(androidSizes)) {
      const outputDir = path.join(androidResDir, folder);
      if (!fs.existsSync(outputDir)) {
        fs.mkdirSync(outputDir, { recursive: true });
      }

      const outputPath = path.join(outputDir, 'ic_launcher.png');
      await image
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toFile(outputPath);

      console.log(`✅ ${folder}/ic_launcher.png (${size}x${size}px)`);
    }

    // Gera ícones redondos (ic_launcher_round.png)
    for (const [folder, size] of Object.entries(androidSizes)) {
      const outputDir = path.join(androidResDir, folder);
      const outputPath = path.join(outputDir, 'ic_launcher_round.png');

      // Cria uma imagem redonda com fundo transparente
      const rounded = await sharp({
        create: {
          width: size,
          height: size,
          channels: 4,
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        }
      })
        .composite([
          {
            input: await image
              .resize(size, size, { fit: 'contain' })
              .png()
              .toBuffer(),
            blend: 'over'
          }
        ])
        .png()
        .toFile(outputPath);

      console.log(`✅ ${folder}/ic_launcher_round.png (${size}x${size}px)`);
    }

    // Gera foreground para adaptive icons (ic_launcher_foreground.png)
    for (const [folder, size] of Object.entries(foregroundSizes)) {
      const outputDir = path.join(androidResDir, folder);
      const outputPath = path.join(outputDir, 'ic_launcher_foreground.png');

      await image
        .resize(size, size, {
          fit: 'contain',
          background: { r: 0, g: 0, b: 0, alpha: 0 }
        })
        .png()
        .toFile(outputPath);

      console.log(`✅ ${folder}/ic_launcher_foreground.png (${size}x${size}px)`);
    }

    console.log('\n✨ Ícones gerados com sucesso!');
    console.log('📱 Agora você pode compilar o app Android e o logo será usado automaticamente.');

  } catch (error) {
    console.error('❌ Erro ao gerar ícones:', error.message);
    process.exit(1);
  }
}

generateIcons();

