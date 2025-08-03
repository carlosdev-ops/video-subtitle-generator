#!/bin/bash

# Script pour créer un package de déploiement complet
# Usage: ./create_deployment_package.sh

PACKAGE_NAME="video-subtitle-generator"
PACKAGE_DIR="${PACKAGE_NAME}"
ZIP_FILE="${PACKAGE_NAME}-$(date +%Y%m%d-%H%M%S).zip"

echo "📦 Création du package de déploiement..."

# Nettoyage si le dossier existe déjà
if [ -d "$PACKAGE_DIR" ]; then
    rm -rf "$PACKAGE_DIR"
fi

# Création de la structure de répertoires
echo "📁 Création de la structure..."
mkdir -p "$PACKAGE_DIR"/{input,output,script}

# Création du README.md
echo "📝 Création de la documentation..."
cat > "$PACKAGE_DIR/README.md" << 'EOF'
# Génération automatique de sous-titres VTT (Français → Anglais)

## Vue d'ensemble
Ce projet permet de générer automatiquement des sous-titres anglais au format VTT à partir d'une vidéo en français québécois.

**Pipeline complet :**
Vidéo MP4 (FR) → Audio WAV → Transcription SRT (FR) → Traduction SRT (EN) → Fichier VTT (EN)

---

## 1. Prérequis système

### Packages système requis (Ubuntu/Debian)
```bash
sudo apt update
sudo apt install -y python3 python3-pip python3-venv ffmpeg git
```

### Packages système requis (CentOS/RHEL/Fedora)
```bash
# CentOS/RHEL
sudo yum install -y python3 python3-pip ffmpeg git
# ou Fedora
sudo dnf install -y python3 python3-pip ffmpeg git
```

### Vérification des prérequis
```bash
# Vérifiez que tout est installé
python3 --version    # Doit afficher Python 3.7+
pip3 --version       # Doit afficher pip
ffmpeg -version      # Doit afficher FFmpeg
```

---

## 2. Installation rapide

```bash
# 1. Extraire le package
unzip video-subtitle-generator-*.zip
cd video-subtitle-generator

# 2. Installer et valider
./install.sh

# 3. Utiliser
cp /chemin/vers/video.mp4 input/video.mp4
./generate_subtitles.sh
```

---

## 3. Installation manuelle

### A. Configuration de l'environnement virtuel Python
```bash
# Créez l'environnement virtuel
python3 -m venv venv

# Activez l'environnement virtuel
source venv/bin/activate

# Installez les dépendances
pip install --upgrade pip
pip install openai-whisper deep-translator pathlib
```

### B. Validation
```bash
./validate_environment.sh
```

---

## 4. Utilisation

### Mode automatique (recommandé)
```bash
# 1. Placer votre vidéo
cp /chemin/vers/votre/video.mp4 input/video.mp4

# 2. Générer les sous-titres
./generate_subtitles.sh

# 3. Récupérer le résultat
# Le fichier sera dans: output/subtitles_en.vtt
```

### Mode manuel (étape par étape)
```bash
# Activer l'environnement
source venv/bin/activate

# Pipeline manuel
./script/extract_audio.sh
python script/transcribe_srt.py      # ⏱️ Étape la plus longue (5-60 min)
python script/translate_srt.py       # ⏱️ Rapide (1-5 min)
python script/convert_srt_to_vtt.py  # ⏱️ Très rapide (<30 sec)
```

---

## 5. Validation des résultats

```bash
# Vérifier la transcription française
head -20 output/subtitles_fr.srt

# Vérifier la traduction anglaise
head -20 output/subtitles_en.srt

# Vérifier le fichier final VTT
ls -la output/subtitles_en.vtt
```

---

## 6. Structure du projet

```
video-subtitle-generator/
├── README.md                      # Cette documentation
├── install.sh                     # Installation automatique
├── validate_environment.sh        # Validation de l'environnement
├── generate_subtitles.sh          # Génération automatique
├── input/
│   └── video.mp4                 # Placez votre vidéo ici
├── output/                       # Fichiers générés
└── script/                       # Scripts de traitement
```

---

## 7. Dépannage

### "Module not found"
```bash
source venv/bin/activate
pip install openai-whisper deep-translator pathlib
```

### "FFmpeg not found"
```bash
sudo apt install ffmpeg  # Ubuntu/Debian
sudo yum install ffmpeg  # CentOS/RHEL
```

### Transcription lente
- Normal pour la première utilisation (téléchargement du modèle ~3GB)
- Les utilisations suivantes seront plus rapides

---

## Support

Pour toute question ou problème, vérifiez d'abord :
1. Les prérequis système sont installés
2. L'environnement virtuel est activé
3. Les dépendances Python sont installées
4. Le fichier `input/video.mp4` existe
EOF

# Création du script d'installation automatique
echo "🔧 Création du script d'installation..."
cat > "$PACKAGE_DIR/install.sh" << 'EOF'
#!/bin/bash
set -e

echo "🚀 Installation de video-subtitle-generator"

# Vérification des prérequis système
echo "🔍 Vérification des prérequis système..."

if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 non trouvé. Installez-le avec:"
    echo "   Ubuntu/Debian: sudo apt install python3 python3-pip python3-venv"
    echo "   CentOS/RHEL:   sudo yum install python3 python3-pip"
    exit 1
fi

if ! command -v ffmpeg &> /dev/null; then
    echo "❌ FFmpeg non trouvé. Installez-le avec:"
    echo "   Ubuntu/Debian: sudo apt install ffmpeg"
    echo "   CentOS/RHEL:   sudo yum install ffmpeg"
    exit 1
fi

echo "✅ Prérequis système OK"

# Création de l'environnement virtuel
echo "🐍 Création de l'environnement virtuel Python..."
python3 -m venv venv

# Activation et installation des dépendances
echo "📦 Installation des dépendances Python..."
source venv/bin/activate
pip install --upgrade pip
pip install openai-whisper deep-translator pathlib

# Permissions des scripts
echo "🔑 Configuration des permissions..."
chmod +x validate_environment.sh
chmod +x generate_subtitles.sh
chmod +x script/extract_audio.sh

# Validation finale
echo "✅ Validation de l'installation..."
source venv/bin/activate
./validate_environment.sh

echo ""
echo "🎉 Installation terminée avec succès !"
echo ""
echo "Pour utiliser:"
echo "1. cp /chemin/vers/video.mp4 input/video.mp4"
echo "2. ./generate_subtitles.sh"
echo ""
EOF

chmod +x "$PACKAGE_DIR/install.sh"

# Création du script de validation
echo "🔍 Création du script de validation..."
cat > "$PACKAGE_DIR/validate_environment.sh" << 'EOF'
#!/bin/bash

echo "🔍 Validation de l'environnement..."

# Vérification de la structure des dossiers
echo "📁 Vérification des dossiers..."
for dir in input output script; do
    if [ -d "$dir" ]; then
        echo "  ✅ $dir/"
    else
        echo "  ❌ $dir/ manquant"
        mkdir -p "$dir"
        echo "     → Créé automatiquement"
    fi
done

# Vérification de l'environnement virtuel
echo "🐍 Vérification de l'environnement Python..."
if [ -d "venv" ]; then
    echo "  ✅ Environnement virtuel présent"
else
    echo "  ❌ Environnement virtuel manquant"
    echo "     → Exécutez: ./install.sh"
    exit 1
fi

# Vérification de l'activation
if [[ "$VIRTUAL_ENV" == *"venv"* ]]; then
    echo "  ✅ Environnement virtuel activé"
else
    echo "  ❌ Environnement virtuel non activé"
    echo "     → Exécutez: source venv/bin/activate"
    exit 1
fi

# Vérification des dépendances Python
echo "📦 Vérification des dépendances Python..."
python -c "import whisper; print('  ✅ whisper')" 2>/dev/null || echo "  ❌ whisper manquant"
python -c "import deep_translator; print('  ✅ deep_translator')" 2>/dev/null || echo "  ❌ deep_translator manquant"

# Vérification des outils système
echo "🔧 Vérification des outils système..."
which ffmpeg >/dev/null && echo "  ✅ ffmpeg" || echo "  ❌ ffmpeg manquant"
which python3 >/dev/null && echo "  ✅ python3" || echo "  ❌ python3 manquant"

# Vérification des scripts
echo "📝 Vérification des scripts..."
for script in extract_audio.sh transcribe_srt.py translate_srt.py convert_srt_to_vtt.py; do
    if [ -f "script/$script" ]; then
        echo "  ✅ script/$script"
    else
        echo "  ❌ script/$script manquant"
    fi
done

echo "✅ Validation terminée !"
EOF

chmod +x "$PACKAGE_DIR/validate_environment.sh"

# Création du script automatique principal
echo "🤖 Création du script de génération automatique..."
cat > "$PACKAGE_DIR/generate_subtitles.sh" << 'EOF'
#!/bin/bash
set -e

echo "🎬 Génération automatique de sous-titres VTT"

# Activation de l'environnement virtuel
if [ -d "venv" ]; then
    source venv/bin/activate
else
    echo "❌ Environnement virtuel non trouvé. Exécutez: ./install.sh"
    exit 1
fi

# Validation
./validate_environment.sh

# Vérification du fichier d'entrée
if [ ! -f "input/video.mp4" ]; then
    echo "❌ Placez votre vidéo dans input/video.mp4"
    echo "   Exemple: cp /chemin/vers/votre/video.mp4 input/video.mp4"
    exit 1
fi

echo "📹 Vidéo détectée: input/video.mp4"
echo "⏱️  Estimation: 5-60 minutes selon la durée de la vidéo"
echo ""

# Pipeline complet avec indication de progression
echo "⏳ Étape 1/4 : Extraction audio..."
./script/extract_audio.sh

echo "⏳ Étape 2/4 : Transcription française (peut prendre 5-60 min)..."
echo "   ℹ️  Première utilisation: téléchargement du modèle Whisper (~3GB)"
python script/transcribe_srt.py

echo "⏳ Étape 3/4 : Traduction anglaise..."
python script/translate_srt.py

echo "⏳ Étape 4/4 : Conversion VTT..."
python script/convert_srt_to_vtt.py

echo ""
echo "✅ Terminé ! Fichier généré : output/subtitles_en.vtt"
echo ""
echo "📊 Résumé des fichiers générés:"
ls -la output/
echo ""
echo "🎯 Pour utiliser le fichier VTT:"
echo "   cp output/subtitles_en.vtt /chemin/de/destination/"
EOF

chmod +x "$PACKAGE_DIR/generate_subtitles.sh"

# Création des scripts dans le dossier script/
echo "📝 Création des scripts de traitement..."

# Script d'extraction audio
cat > "$PACKAGE_DIR/script/extract_audio.sh" << 'EOF'
#!/bin/bash

INPUT="input/video.mp4"
OUTPUT="output/audio.wav"

mkdir -p output

if [ ! -f "$INPUT" ]; then
    echo "❌ Fichier non trouvé: $INPUT"
    echo "   Placez votre vidéo dans input/video.mp4"
    exit 1
fi

echo "🎵 Extraction audio de $INPUT vers $OUTPUT"
ffmpeg -y -i "$INPUT" -ac 1 -ar 16000 "$OUTPUT"

if [ -f "$OUTPUT" ]; then
    echo "✅ Audio extrait: $OUTPUT ($(du -h "$OUTPUT" | cut -f1))"
else
    echo "❌ Échec de l'extraction audio"
    exit 1
fi
EOF

chmod +x "$PACKAGE_DIR/script/extract_audio.sh"

# Script de transcription
cat > "$PACKAGE_DIR/script/transcribe_srt.py" << 'EOF'
# script/transcribe_srt.py
import whisper
from pathlib import Path
import sys

input_audio = "output/audio.wav"
output_srt = "output/subtitles_fr.srt"

# Vérification du fichier d'entrée
if not Path(input_audio).exists():
    print(f"❌ Fichier audio non trouvé: {input_audio}")
    print("   Exécutez d'abord: ./script/extract_audio.sh")
    sys.exit(1)

# Liste des modèles par ordre de préférence
models_to_try = ["large-v3", "large-v2", "large", "medium"]

model = None
for model_name in models_to_try:
    try:
        print(f"⏳ Chargement du modèle {model_name}...")
        model = whisper.load_model(model_name)
        print(f"✅ Modèle {model_name} chargé avec succès")
        break
    except Exception as e:
        print(f"❌ Échec du modèle {model_name}: {e}")
        continue

if model is None:
    print("❌ Aucun modèle Whisper disponible")
    sys.exit(1)

print("⏳ Transcription en cours (peut prendre plusieurs minutes)...")
print("   💡 Conseil: La première utilisation télécharge le modèle (~3GB)")

try:
    result = model.transcribe(
        input_audio, 
        language="fr",
        task="transcribe",
        fp16=False,
        temperature=0,
        initial_prompt="Transcription en français québécois du Canada."
    )
except Exception as e:
    print(f"⚠️ Utilisation des paramètres de base: {e}")
    result = model.transcribe(input_audio, language="fr", task="transcribe", fp16=False)

# Sauvegarde en format SRT
with open(output_srt, "w", encoding="utf-8") as f:
    for i, segment in enumerate(result["segments"], start=1):
        start = segment["start"]
        end = segment["end"]
        text = segment["text"].strip()
        
        # Nettoyage du texte
        text = " ".join(text.split())
        if not text:
            continue

        def format_time(t):
            h = int(t // 3600)
            m = int((t % 3600) // 60)
            s = int(t % 60)
            ms = int((t - int(t)) * 1000)
            return f"{h:02}:{m:02}:{s:02},{ms:03}"

        f.write(f"{i}\n{format_time(start)} --> {format_time(end)}\n{text}\n\n")

print(f"✅ Transcription terminée: {output_srt}")
print(f"📊 Langue détectée: {result.get('language', 'N/A')}")
print(f"📊 Nombre de segments: {len(result['segments'])}")
print(f"📊 Taille du fichier: {Path(output_srt).stat().st_size} bytes")
EOF

# Script de traduction
cat > "$PACKAGE_DIR/script/translate_srt.py" << 'EOF'
# script/translate_srt.py
from deep_translator import GoogleTranslator
from pathlib import Path
import re
import sys
import time

input_path = Path("output/subtitles_fr.srt")
output_path = Path("output/subtitles_en.srt")

# Vérification du fichier d'entrée
if not input_path.exists():
    print(f"❌ Fichier SRT français non trouvé: {input_path}")
    print("   Exécutez d'abord: python script/transcribe_srt.py")
    sys.exit(1)

print(f"🌐 Traduction de {input_path} vers {output_path}")

translator = GoogleTranslator(source='fr', target='en')

with input_path.open(encoding='utf-8') as f:
    content = f.read()

# Parse les entrées SRT
entries = re.findall(r'(\d+)\n([\d:,]+ --> [\d:,]+)\n(.*?)\n\n', content, re.DOTALL)

print(f"📝 {len(entries)} segments à traduire...")

translated = []
errors = 0

for index, timecode, text in entries:
    try:
        translated_text = translator.translate(text.strip())
        translated.append(f"{index}\n{timecode}\n{translated_text}\n")
        
        # Petite pause pour éviter les limites de taux
        time.sleep(0.1)
        
        # Progression
        if int(index) % 10 == 0:
            print(f"   📊 Progression: {index}/{len(entries)} segments")
            
    except Exception as e:
        print(f"❌ Erreur traduction segment {index}: {e}")
        translated.append(f"{index}\n{timecode}\n{text.strip()}\n")
        errors += 1

# Sauvegarde
with output_path.open("w", encoding="utf-8") as f:
    f.write("\n".join(translated))

print(f"✅ Traduction terminée: {output_path}")
if errors > 0:
    print(f"⚠️  {errors} segments non traduits (gardés en français)")
print(f"📊 Taille du fichier: {output_path.stat().st_size} bytes")
EOF

# Script de conversion VTT
cat > "$PACKAGE_DIR/script/convert_srt_to_vtt.py" << 'EOF'
# script/convert_srt_to_vtt.py
from pathlib import Path
import re
import sys

input_srt = Path("output/subtitles_en.srt")
output_vtt = Path("output/subtitles_en.vtt")

# Vérification du fichier d'entrée
if not input_srt.exists():
    print(f"❌ Fichier SRT anglais non trouvé: {input_srt}")
    print("   Exécutez d'abord: python script/translate_srt.py")
    sys.exit(1)

print(f"🔄 Conversion {input_srt} → {output_vtt}")

def srt_to_vtt_time(srt_time):
    """Convertit le format de temps SRT vers VTT (remplace ',' par '.')"""
    return srt_time.replace(',', '.')

with input_srt.open(encoding='utf-8') as f:
    content = f.read()

# Parse les entrées SRT
entries = re.findall(r'(\d+)\n([\d:,]+ --> [\d:,]+)\n(.*?)\n\n', content, re.DOTALL)

# Génère le contenu VTT
vtt_content = ["WEBVTT\n"]

for index, timecode, text in entries:
    # Convertit le format de temps
    vtt_timecode = srt_to_vtt_time(timecode)
    vtt_content.append(f"{vtt_timecode}\n{text.strip()}\n")

# Écrit le fichier VTT
with output_vtt.open("w", encoding="utf-8") as f:
    f.write("\n".join(vtt_content))

print(f"✅ Conversion VTT terminée: {output_vtt}")
print(f"📊 {len(entries)} segments convertis")
print(f"📊 Taille du fichier: {output_vtt.stat().st_size} bytes")
EOF

# Création de fichiers d'exemple et d'information
echo "📄 Création des fichiers d'information..."

# Fichier d'information dans input/
cat > "$PACKAGE_DIR/input/README.txt" << 'EOF'
DOSSIER INPUT
=============

Placez votre fichier vidéo ici avec le nom: video.mp4

Exemple:
cp /chemin/vers/votre/video.mp4 ./video.mp4

Formats supportés: MP4, AVI, MOV, MKV (tout format supporté par FFmpeg)

Note: Le fichier doit être nommé exactement "video.mp4" pour que les scripts fonctionnent.
EOF

# Fichier d'information dans output/
cat > "$PACKAGE_DIR/output/README.txt" << 'EOF'
DOSSIER OUTPUT
==============

Ce dossier contiendra les fichiers générés:

1. audio.wav          - Audio extrait de la vidéo
2. subtitles_fr.srt   - Transcription en français
3. subtitles_en.srt   - Traduction en anglais  
4. subtitles_en.vtt   - Fichier final VTT (objectif)

Le fichier final à utiliser est: subtitles_en.vtt
EOF

# Création du fichier de version
cat > "$PACKAGE_DIR/VERSION" << EOF
Package: video-subtitle-generator
Version: 1.0.0
Date: $(date +%Y-%m-%d)
Description: Générateur automatique de sous-titres VTT (Français → Anglais)
EOF

# Création du package ZIP
echo "📦 Création du fichier ZIP..."
zip -r "$ZIP_FILE" "$PACKAGE_DIR" -x "*.DS_Store" "*/__pycache__/*" "*/.*"

# Nettoyage
rm -rf "$PACKAGE_DIR"

# Résumé
echo ""
echo "✅ Package créé avec succès !"
echo ""
echo "📦 Fichier: $ZIP_FILE"
echo "📊 Taille: $(du -h "$ZIP_FILE" | cut -f1)"
echo ""
echo "🚀 Pour déployer sur un autre système:"
echo "   1. Transférez le fichier: $ZIP_FILE"
echo "   2. Extrayez: unzip $ZIP_FILE"
echo "   3. Installez: cd $PACKAGE_NAME && ./install.sh"
echo "   4. Utilisez: cp video.mp4 input/ && ./generate_subtitles.sh"
echo ""
echo "📋 Contenu du package:"
unzip -l "$ZIP_FILE" | head -20
echo "   ... (voir le ZIP complet pour tous les fichiers)"
