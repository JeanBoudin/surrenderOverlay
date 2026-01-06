# Build et Distribution de SurrenderOverlay

## Méthode 1 : Build simple (pour partager localement)

### Dans Xcode

1. **Sélectionner le scheme de Release** :
   - Product → Scheme → Edit Scheme
   - Dans "Run", changer "Build Configuration" de "Debug" à "Release"
   - Ou simplement : Product → Archive (qui utilise automatiquement Release)

2. **Archive l'application** :
   - Product → Archive (⌘+B après avoir sélectionné "Any Mac")
   - Attendre la fin de l'archivage
   - La fenêtre "Organizer" s'ouvre automatiquement

3. **Exporter l'application** :
   - Dans Organizer, sélectionner l'archive
   - Cliquer sur "Distribute App"
   - Choisir **"Copy App"** (pour distribution directe)
   - Cliquer sur "Next" → "Export"
   - Choisir un dossier de destination

4. **L'app est prête** :
   - Vous obtenez un fichier `SurrenderOverlay.app`
   - Vous pouvez le compresser en ZIP ou créer un DMG

### Via la ligne de commande

```bash
cd /Users/m.vaugoyeau/Projets/SurrenderOverlay

# Build Release
xcodebuild -project SurrenderOverlay.xcodeproj \
  -scheme SurrenderOverlay \
  -configuration Release \
  -derivedDataPath build

# L'app est dans :
# build/Build/Products/Release/SurrenderOverlay.app
```

---

## Méthode 2 : Créer un DMG (recommandé pour distribution)

### Avec create-dmg (automatique)

```bash
# Installer create-dmg
brew install create-dmg

# Build l'app d'abord (voir ci-dessus)

# Créer le DMG
create-dmg \
  --volname "SurrenderOverlay" \
  --volicon "SurrenderOverlay/Assets.xcassets/AppIcon.appiconset/icon_512x512.png" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "SurrenderOverlay.app" 175 120 \
  --hide-extension "SurrenderOverlay.app" \
  --app-drop-link 425 120 \
  "SurrenderOverlay-1.0.1.dmg" \
  "build/Build/Products/Release/"
```

### Manuellement avec Disk Utility

1. Ouvrir **Disk Utility**
2. File → New Image → Blank Image
3. Nom : "SurrenderOverlay"
4. Size : 100 MB
5. Format : Mac OS Extended
6. Image Format : read/write disk image
7. Sauvegarder

8. Monter l'image, copier `SurrenderOverlay.app` dedans
9. Créer un lien symbolique vers `/Applications`
10. Éjecter
11. Convertir en read-only :
   ```bash
   hdiutil convert temp.dmg -format UDZO -o SurrenderOverlay-1.0.1.dmg
   ```

---

## Méthode 3 : Notarisation (pour distribution publique)

⚠️ **Requis pour que l'app s'ouvre sans warning "app provenant d'un développeur non identifié"**

### Prérequis

- Apple Developer Account (99$/an)
- Developer ID Application certificate
- App-specific password pour notarization

### Étapes

1. **Signer l'app** :
   ```bash
   codesign --deep --force --verify --verbose \
     --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
     --options runtime \
     SurrenderOverlay.app
   ```

2. **Créer le DMG signé** (voir Méthode 2)

3. **Notarize** :
   ```bash
   # Créer un ZIP
   ditto -c -k --keepParent SurrenderOverlay.app SurrenderOverlay.zip

   # Soumettre pour notarization
   xcrun notarytool submit SurrenderOverlay.zip \
     --apple-id "your@email.com" \
     --team-id "TEAM_ID" \
     --password "app-specific-password" \
     --wait

   # Stapler le ticket
   xcrun stapler staple SurrenderOverlay.app
   ```

4. **Créer le DMG final** avec l'app notarisée

---

## Méthode 4 : Simple ZIP (le plus rapide)

```bash
cd build/Build/Products/Release/

# Créer un ZIP
ditto -c -k --sequesterRsrc --keepParent \
  SurrenderOverlay.app \
  SurrenderOverlay-1.0.1.zip
```

Partager le ZIP directement !

---

## Script automatique

Créer un fichier `build-release.sh` :

```bash
#!/bin/bash

VERSION="1.0.1"
APP_NAME="SurrenderOverlay"

echo "🔨 Building ${APP_NAME} v${VERSION}..."

# Clean
rm -rf build/

# Build
xcodebuild -project ${APP_NAME}.xcodeproj \
  -scheme ${APP_NAME} \
  -configuration Release \
  -derivedDataPath build \
  clean build

if [ $? -eq 0 ]; then
  echo "✅ Build successful!"

  # Create ZIP
  cd build/Build/Products/Release/
  ditto -c -k --sequesterRsrc --keepParent \
    ${APP_NAME}.app \
    ${APP_NAME}-${VERSION}.zip

  echo "📦 Created: ${APP_NAME}-${VERSION}.zip"
  echo "📍 Location: $(pwd)/${APP_NAME}-${VERSION}.zip"
else
  echo "❌ Build failed"
  exit 1
fi
```

Utilisation :
```bash
chmod +x build-release.sh
./build-release.sh
```

---

## Distribution

### Pour partager avec des amis/testeurs :

1. **ZIP** (le plus simple) :
   - Envoyer le `.zip` par email, Dropbox, Google Drive, etc.
   - Ils doivent le décompresser et déplacer l'app dans `/Applications`

2. **DMG** (plus professionnel) :
   - Partager le `.dmg`
   - Ils double-cliquent, et drag & drop dans Applications

### Pour distribution publique :

1. **GitHub Releases** :
   - Créer un release tag
   - Upload le DMG/ZIP
   - Les utilisateurs téléchargent depuis GitHub

2. **Sparkle (déjà intégré !)** :
   - Votre app utilise déjà Sparkle pour les auto-updates
   - Héberger le DMG + `appcast.xml` quelque part
   - Les utilisateurs reçoivent les updates automatiquement

3. **App Store** (option payante) :
   - Nécessite Apple Developer Program (99$/an)
   - Distribution via Mac App Store

---

## Problèmes courants

### "App is damaged and can't be opened"

L'utilisateur doit :
```bash
xattr -cr /Applications/SurrenderOverlay.app
```

Ou vous devez **notarize** l'app (Méthode 3)

### "App from unidentified developer"

L'utilisateur doit :
- Clic droit → Open
- Ou : System Settings → Privacy & Security → "Open Anyway"

Ou vous devez **notarize** l'app

### L'app ne se lance pas

Vérifier que toutes les dépendances (Starscream, Sparkle) sont bien incluses :
```bash
otool -L SurrenderOverlay.app/Contents/MacOS/SurrenderOverlay
```

---

## Checklist avant distribution

- [ ] Version number mise à jour dans `Info.plist`
- [ ] Backend URL configurée (Railway, pas localhost)
- [ ] Build en mode Release (pas Debug)
- [ ] Testé sur une machine fraîche
- [ ] README/Documentation inclus
- [ ] Sparkle appcast.xml à jour (si auto-updates)

---

## Prêt ! 🚀

Votre app est maintenant prête à être partagée !
