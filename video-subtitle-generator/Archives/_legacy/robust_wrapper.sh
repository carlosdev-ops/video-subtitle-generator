#!/bin/bash

# Wrapper robuste avec gestion des blocages et timeouts intelligents
echo "🛡️ Version robuste avec gestion des blocages"

# Stopper tous les processus précédents
pkill -f generate_subtitles 2>/dev/null || true
pkill -f python 2>/dev/null || true
pkill -f whisper 2>/dev/null || true

# Fonction pour calculer timeout intelligent
calculate_timeout() {
    local file_path="$1"
    local duration_sec=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$file_path" 2>/dev/null | cut -d. -f1)
    
    # Si on ne peut pas déterminer la durée, utiliser la taille du fichier
    if [ -z "$duration_sec" ] || [ "$duration_sec" -eq 0 ]; then
        local size_mb=$(du -m "$file_path" | cut -f1)
        duration_sec=$((size_mb * 3)) # 3 secondes par MB approximativement
    fi
    
    # Timeout = durée * 10 (facteur de sécurité) + 300 secondes de base
    local timeout_sec=$((duration_sec * 10 + 300))
    
    # Minimum 5 minutes, maximum 1 heure
    [ $timeout_sec -lt 300 ] && timeout_sec=300
    [ $timeout_sec -gt 3600 ] && timeout_sec=3600
    
    echo $timeout_sec
}

# Fonction pour vérifier si un processus est bloqué
is_process_stuck() {
    local pid=$1
    local max_idle_time=600  # 10 minutes sans activité = bloqué
    
    # Vérifier l'activité CPU du processus
    local cpu_usage=$(ps -p $pid -o %cpu --no-headers 2>/dev/null | tr -d ' ')
    
    if [ -z "$cpu_usage" ]; then
        return 0  # Processus n'existe plus
    fi
    
    # Si CPU < 1% pendant trop longtemps, considérer comme bloqué
    if (( $(echo "$cpu_usage < 1.0" | bc -l) )); then
        return 0  # Potentiellement bloqué
    fi
    
    return 1  # Processus actif
}

# Créer les dossiers
mkdir -p output output_final logs

# Détecter les vidéos
echo "🎬 Recherche des vidéos..."
cd input
VIDEOS=(*.mp4 *.mov *.avi *.mkv *.wmv)
REAL_VIDEOS=()
for video in "${VIDEOS[@]}"; do
    if [ -f "$video" ] && [[ ! "$video" =~ ^SKIP_ ]]; then
        REAL_VIDEOS+=("$video")
    fi
done
cd ..

if [ ${#REAL_VIDEOS[@]} -eq 0 ]; then
    echo "❌ Aucune vidéo trouvée (les fichiers SKIP_* sont ignorés)"
    exit 1
fi

echo "✅ ${#REAL_VIDEOS[@]} vidéo(s) à traiter:"
for video in "${REAL_VIDEOS[@]}"; do
    duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "input/$video" 2>/dev/null | cut -d. -f1)
    size_mb=$(du -m "input/$video" | cut -f1)
    timeout_min=$(( $(calculate_timeout "input/$video") / 60 ))
    
    echo "   - $video (${size_mb}MB, ${duration}s, timeout: ${timeout_min}min)"
done

echo ""
read -p "Continuer? [Y/n] " -n 1 -r
echo
[[ $REPLY =~ ^[Nn]$ ]] && exit 0

# Compteurs
SUCCESS=0
FAILED=0
SKIPPED=0

# Fichier pour les vidéos problématiques
PROBLEM_LOG="logs/problematic_videos.txt"
echo "# Vidéos ayant causé des problèmes - $(date)" > "$PROBLEM_LOG"

# Traiter chaque vidéo
for i in "${!REAL_VIDEOS[@]}"; do
    VIDEO="${REAL_VIDEOS[$i]}"
    NUM=$((i + 1))
    TOTAL=${#REAL_VIDEOS[@]}
    
    echo ""
    echo "=============================================="
    echo "📹 [$NUM/$TOTAL] Traitement: $VIDEO"
    echo "=============================================="
    
    # Calculer timeout intelligent
    TIMEOUT_SEC=$(calculate_timeout "input/$VIDEO")
    TIMEOUT_MIN=$((TIMEOUT_SEC / 60))
    
    echo "⏱️  Timeout configuré: ${TIMEOUT_MIN} minutes"
    
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
    
    # Lancement avec timeout intelligent et surveillance
    echo "🔄 Lancement avec surveillance anti-blocage..."
    START_TIME=$(date +%s)
    
    # Lancer le script avec timeout
    timeout $TIMEOUT_SEC ./generate_subtitles.sh &
    SCRIPT_PID=$!
    
    # Surveillance en arrière-plan
    (
        sleep 600  # Attendre 10 minutes avant de commencer la surveillance
        while kill -0 $SCRIPT_PID 2>/dev/null; do
            if is_process_stuck $SCRIPT_PID; then
                echo "⚠️  Processus potentiellement bloqué détecté"
                # Laisser encore 5 minutes avant d'abandonner
                sleep 300
                if kill -0 $SCRIPT_PID 2>/dev/null && is_process_stuck $SCRIPT_PID; then
                    echo "🚨 Processus définitivement bloqué - Arrêt forcé"
                    kill -TERM $SCRIPT_PID 2>/dev/null
                    sleep 5
                    kill -KILL $SCRIPT_PID 2>/dev/null
                    break
                fi
            fi
            sleep 60  # Vérifier chaque minute
        done
    ) &
    MONITOR_PID=$!
    
    # Attendre la fin du script
    if wait $SCRIPT_PID; then
        kill $MONITOR_PID 2>/dev/null || true
        
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        echo "✅ Script terminé en $((DURATION / 60))m$((DURATION % 60))s"
        
        # Vérifier les fichiers générés
        if [ -f "output/subtitles_en.vtt" ]; then
            echo "✅ Fichier VTT trouvé"
            
            # Sauvegarder
            VIDEO_NAME=$(echo "$VIDEO" | sed 's/\.[^.]*$//' | sed 's/[^a-zA-Z0-9._-]/_/g')
            FINAL_DIR="output_final/$VIDEO_NAME"
            mkdir -p "$FINAL_DIR"
            
            cp -r output/* "$FINAL_DIR/"
            echo "✅ Fichiers sauvés dans: $FINAL_DIR/"
            SUCCESS=$((SUCCESS + 1))
        else
            echo "❌ Fichier VTT non généré"
            FAILED=$((FAILED + 1))
            echo "$VIDEO - VTT non généré" >> "$PROBLEM_LOG"
        fi
    else
        kill $MONITOR_PID 2>/dev/null || true
        
        echo "❌ Script a échoué ou timeout atteint"
        echo "🔄 Déplacement vers SKIP pour éviter les re-tentatives..."
        
        # Déplacer la vidéo problématique
        mv "input/$VIDEO" "input/SKIP_${VIDEO}"
        echo "$VIDEO - Timeout ou échec (déplacé vers SKIP_${VIDEO})" >> "$PROBLEM_LOG"
        
        SKIPPED=$((SKIPPED + 1))
    fi
    
    # Nettoyage pour la prochaine itération
    rm -f input/video.mp4
    
    # Nettoyer les processus orphelins
    pkill -f whisper 2>/dev/null || true
    pkill -f python.*transcribe 2>/dev/null || true
done

# Résumé final
echo ""
echo "=============================================="
echo "📊 RÉSUMÉ FINAL"
echo "=============================================="
echo "✅ Réussis: $SUCCESS"
echo "❌ Échecs:  $FAILED"
echo "⏭️  Ignorés: $SKIPPED"
echo "📂 Résultats dans: output_final/"

if [ $SKIPPED -gt 0 ]; then
    echo ""
    echo "⚠️  Vidéos problématiques déplacées vers SKIP_*"
    echo "   Voir détails dans: $PROBLEM_LOG"
    echo "   Vous pouvez les retraiter individuellement si nécessaire"
fi

if [ $SUCCESS -gt 0 ]; then
    echo ""
    echo "🎯 Fichiers VTT générés:"
    find output_final -name "*.vtt" -exec echo "   {}" \;
fi
