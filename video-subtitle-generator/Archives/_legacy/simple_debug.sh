#!/bin/bash

# Wrapper ultra-simple pour debug
echo "🔧 Version debug ultra-simple"

# Stopper tous les processus précédents
pkill -f generate_subtitles 2>/dev/null || true
pkill -f timeout 2>/dev/null || true

# Vérifications de base
echo "📁 Vérification environnement..."
echo "   Répertoire courant: $(pwd)"
echo "   Script original: $(ls -la generate_subtitles.sh 2>/dev/null || echo 'MANQUANT')"
echo "   Dossier input: $(ls input/ | wc -l) fichiers"

# Créer les dossiers manquants
mkdir -p output output_final logs
echo "   Dossiers créés: output/, output_final/, logs/"

# Détecter les vidéos (méthode simple)
echo ""
echo "🎬 Recherche des vidéos..."
cd input
VIDEOS=(*.mp4 *.mov *.avi *.mkv *.wmv)
REAL_VIDEOS=()
for video in "${VIDEOS[@]}"; do
    if [ -f "$video" ]; then
        REAL_VIDEOS+=("$video")
    fi
done
cd ..

if [ ${#REAL_VIDEOS[@]} -eq 0 ]; then
    echo "❌ Aucune vidéo trouvée dans input/"
    exit 1
fi

echo "✅ ${#REAL_VIDEOS[@]} vidéo(s) trouvée(s):"
for video in "${REAL_VIDEOS[@]}"; do
    echo "   - $video"
done

echo ""
echo "🚀 Traitement séquentiel..."

# Compteurs
SUCCESS=0
FAILED=0

# Traiter chaque vidéo
for i in "${!REAL_VIDEOS[@]}"; do
    VIDEO="${REAL_VIDEOS[$i]}"
    NUM=$((i + 1))
    TOTAL=${#REAL_VIDEOS[@]}
    
    echo ""
    echo "=============================================="
    echo "📹 [$NUM/$TOTAL] Traitement: $VIDEO"
    echo "=============================================="
    
    # Nettoyage
    rm -rf output/*
    rm -f input/video.mp4
    
    # Copie de la vidéo
    echo "📁 Copie: $VIDEO → video.mp4"
    if ! cp "input/$VIDEO" "input/video.mp4"; then
        echo "❌ Échec copie"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Test d'existence du script
    if [ ! -f "./generate_subtitles.sh" ]; then
        echo "❌ Script generate_subtitles.sh non trouvé"
        FAILED=$((FAILED + 1))
        continue
    fi
    
    # Lancement avec logs directs (pas de redirection)
    echo "🔄 Lancement du script original..."
    echo "   Commande: ./generate_subtitles.sh"
    echo "   Démarrage: $(date)"
    
    # Lancer SANS timeout et SANS redirection pour voir les erreurs
    if ./generate_subtitles.sh; then
        echo "✅ Script terminé avec succès"
        
        # Vérifier les fichiers générés
        if [ -f "output/subtitles_en.vtt" ]; then
            echo "✅ Fichier VTT trouvé"
            
            # Sauvegarder dans un dossier dédié
            VIDEO_NAME=$(echo "$VIDEO" | sed 's/\.[^.]*$//' | sed 's/[^a-zA-Z0-9._-]/_/g')
            FINAL_DIR="output_final/$VIDEO_NAME"
            mkdir -p "$FINAL_DIR"
            
            cp -r output/* "$FINAL_DIR/"
            echo "✅ Fichiers sauvés dans: $FINAL_DIR/"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ Fichier VTT non généré"
            FAILED=$((FAILED + 1))
        fi
    else
        echo "❌ Script a échoué (code de retour: $?)"
        FAILED=$((FAILED + 1))
    fi
    
    echo "   Fin: $(date)"
    
    # Nettoyage pour la prochaine itération
    rm -f input/video.mp4
done

# Résumé final
echo ""
echo "=============================================="
echo "📊 RÉSUMÉ FINAL"
echo "=============================================="
echo "✅ Réussis: $SUCCESS"
echo "❌ Échecs:  $FAILED"
echo "📂 Résultats dans: output_final/"

if [ $SUCCESS -gt 0 ]; then
    echo ""
    echo "🎯 Fichiers VTT générés:"
    find output_final -name "*.vtt" -exec echo "   {}" \;
fi
