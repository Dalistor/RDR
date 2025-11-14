# Logo do App

## Como usar

1. **Coloque seu logo aqui**
   - Nome do arquivo: `logo.png` (ou `logo.jpg`, `logo.jpeg`, `logo.webp`)
   - Tamanho recomendado: **1024x1024px** ou maior
   - Formato: PNG (com transparência) ou JPG
   - O logo deve ser **quadrado** para melhor resultado

2. **Gere os ícones automaticamente**
   ```bash
   npm run generate-icons
   ```

3. **Compile o app**
   ```bash
   quasar build
   ```

O script irá gerar automaticamente todos os tamanhos necessários para Android:
- `ic_launcher.png` (ícone normal)
- `ic_launcher_round.png` (ícone redondo)
- `ic_launcher_foreground.png` (para adaptive icons)

Os ícones serão gerados em:
`src-capacitor/android/app/src/main/res/mipmap-*/`

## Tamanhos gerados

- **mdpi**: 48x48px
- **hdpi**: 72x72px
- **xhdpi**: 96x96px
- **xxhdpi**: 144x144px
- **xxxhdpi**: 192x192px

## Dica

Se você não tiver um logo quadrado, o script irá ajustar automaticamente mantendo as proporções e adicionando transparência ao redor.


