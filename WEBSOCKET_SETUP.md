# WebSocket Integration Setup

## Étape 1: Ajouter Starscream via Swift Package Manager

1. Ouvrir `SurrenderOverlay.xcodeproj` dans Xcode
2. Aller dans **File → Add Package Dependencies...**
3. Dans le champ de recherche, entrer: `https://github.com/daltoniam/Starscream.git`
4. Sélectionner **Dependency Rule**: "Up to Next Major Version" avec "4.0.0"
5. Cliquer sur **Add Package**
6. Sélectionner **Starscream** et cliquer sur **Add Package**

## Étape 2: Vérifier que le fichier WebSocketPeerService.swift est ajouté au projet

Le fichier `WebSocketPeerService.swift` a été créé. Il faut l'ajouter au projet Xcode:

1. Dans Xcode, faire un clic droit sur le dossier `SurrenderOverlay` dans le navigateur de projet
2. Choisir **Add Files to "SurrenderOverlay"...**
3. Sélectionner `WebSocketPeerService.swift`
4. Cocher **Copy items if needed**
5. Cocher le target **SurrenderOverlay**
6. Cliquer sur **Add**

## Étape 3: Build le projet

Une fois Starscream ajouté, essayer de build le projet (⌘+B) pour vérifier qu'il n'y a pas d'erreurs.

## Note

Les fichiers `SurrenderOverlayApp.swift` et `PeersView.swift` seront mis à jour automatiquement par Claude pour utiliser le nouveau service WebSocket.
