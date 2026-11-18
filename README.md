# GeoBridge

Application macOS qui simule la position GPS de ton propre iPhone via les outils développeur d'Apple (pas de jailbreak).

## Prérequis

- macOS 14 ou plus récent
- Xcode ou les Command Line Tools (`xcode-select --install`), Swift 5.9+
- Python 3 et [pymobiledevice3](https://github.com/doronz88/pymobiledevice3), installé de préférence avec pipx :

```bash
brew install pipx
pipx install pymobiledevice3
```

- Un iPhone avec le mode développeur activé (Réglages → Confidentialité et sécurité → Mode développeur)

## Build

```bash
git clone https://github.com/Hegowo/GeoBridge.git
cd GeoBridge
bash build-app.sh
```

Le script compile en release, assemble `GeoBridge.app` à la racine du projet, le signe en ad hoc puis le lance.

Pour lancer sans créer le bundle :

```bash
swift build
swift run
```

Pour lancer les tests :

```bash
swift test
```

Pour travailler dans Xcode, `bash setup.sh` génère `GeoBridge.xcodeproj`.

## Utilisation

1. Branche l’iPhone en USB et accepte « Faire confiance à cet ordinateur » (le Wi-Fi marche ensuite).
2. Sur iOS 17 et plus, démarre le tunnel, depuis l'app (bouton du panneau « Tunnel Daemon ») ou dans un terminal :

```bash
sudo pymobiledevice3 remote tunneld
```

3. Choisis un lieu sur la carte, par recherche ou par coordonnées, puis clique sur « Change Location ».
4. « Reset Real Location » rend la vraie position à l'iPhone.

## Release précompilée

La page [Releases](https://github.com/Hegowo/GeoBridge/releases) fournit `GeoBridge.app` zippé. L'app n'est pas notariée : au premier lancement, fais un clic droit → Ouvrir, ou lance :

```bash
xattr -cr GeoBridge.app
```

## Auteur

Kahodev
