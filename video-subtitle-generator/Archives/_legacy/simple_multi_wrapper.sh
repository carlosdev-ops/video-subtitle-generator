#!/bin/bash

# Wrapper simple pour traiter plusieurs vidéos avec monitoring sympathique
# GARDE VOTRE SCRIPT ORIGINAL INTACT - juste l'appelle plusieurs fois
# Usage: ./multi_wrapper.sh

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Animation de progression
SPINNER_CHARS="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
PROGRESS_BARS="▏▎▍▌▋▊▉█"

# Fonction d'animation pendant l'attente
show_progress() {
    local message="$1"
    local duration="$2"
    local steps=$((duration * 4)) # 4 updates par seconde
    
    for ((i=0; i<=steps; i++)); do
        local spinner_char="${SPINNER_CHARS:$((i % ${#SPINNER_CHARS})):1}"
        local progress=$((i * 100 / steps))
        local bar_length=$((progress / 5)) # Barre de 20 caractères max
        
        # Construction de la barre de progression
        local bar=""
        for ((j=0; j<bar_length && j<20; j++)); do
            if [ $j -eq $((bar_length-1)) ] && [ $progress -lt 100 ]; then
                local partial_idx=$((progress % 5))
                [ $partial_idx -gt 0 ] && bar+="${PROGRESS_BARS:$partial_idx:1}" || bar+="█"
            else
                bar+="█"
            fi
        done
        
        # Compléter la barre avec des espaces
        while [ ${#bar} -lt 20 ]; do
            bar+="░"
        done
        
        printf "\r${CYAN}$spinner_char${NC} $message ${BLUE}[$bar]${NC} ${WHITE}$progress%%${NC}"
        sleep 0.25
        
        # Sortir si le processus est terminé
        [ ! -f "/tmp/processing_active" ] && break
    done
    printf "\n"
}

# Fonction pour estimer la durée basée sur la taille du fichier
estimate_duration() {
    local file_size_mb=$(du -m "$1" 2>/dev/null | cut -f1)
    # Estimation très approximative: ~2-5 minutes par 100MB
    local estimated_minutes=$((file_size_mb * 3 / 100))
    [ $estimated_minutes -lt 2 ] && estimated_minutes=2
    [ $estimated_minutes -gt 60 ] && estimated_minutes=60
    echo $estimated_minutes
}

# Animation d'introduction
intro_animation() {
    echo -e "${PURPLE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}    🎬 ${WHITE}GÉNÉRATEUR MULTI-SOUS-TITRES${NC}    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}       ${CYAN}Version Sympathique v2.0${NC}        ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════╝${NC}"
    echo ""
    
    # Animation des points
    for i in {1..3}; do
        printf "${YELLOW}Initialisation"
        for j in {1..3}; do
            sleep 0.3
            printf "."
        done
        sleep 0.3
        printf "\r                    \r"
    done
    
    echo -e "${GREEN}✨ Prêt à traiter vos vidéos !${NC}\n"
}

intro_animation

echo -e "${WHITE}📝 Garde votre script original intact !${NC}"

# Vérification que le script original existe
if [ ! -f "./generate_subtitles.sh" ]; then
    echo -e "${RED}❌ Script original './generate_subtitles.sh' non trouvé${NC}"
    echo -e "${WHITE}   Placez ce wrapper dans le même dossier que votre script qui marche${NC}"
    exit 1
fi

# Détection automatique de l'environnement virtuel
AUTO_VENV_ACTIVATION=""
if [ -d "venv" ]; then
    echo -e "${CYAN}🐍 Environnement virtuel détecté${NC}"
    
    # Vérifier si le script original active déjà l'environnement
    if grep -q "source.*venv.*activate" "./generate_subtitles.sh" 2>/dev/null; then
        echo -e "${GREEN}   ✅ Script original gère déjà l'activation${NC}"
    else
        echo -e "${YELLOW}   ⚠️  Script original n'active pas l'environnement${NC}"
        echo -e "${WHITE}   → Le wrapper va l'activer automatiquement${NC}"
        AUTO_VENV_ACTIVATION="source venv/bin/activate &&"
    fi
else
    echo -e "${WHITE}ℹ️  Aucun environnement virtuel détecté (utilisation globale)${NC}"
fi

# Création des dossiers de logs
mkdir -p logs
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_FILE="logs/multi_processing_${TIMESTAMP}.log"

# Fonction de logging avec couleurs
log() {
    local message="$1"
    local level="${2:-info}"
    local timestamp=$(date "+%H:%M:%S")
    
    case $level in
        "success") echo -e "${GREEN}[$timestamp] ✅ $message${NC}" | tee -a "$LOG_FILE" ;;
        "error")   echo -e "${RED}[$timestamp] ❌ $message${NC}" | tee -a "$LOG_FILE" ;;
        "warning") echo -e "${YELLOW}[$timestamp] ⚠️  $message${NC}" | tee -a "$LOG_FILE" ;;
        "info")    echo -e "${BLUE}[$timestamp] ℹ️  $message${NC}" | tee -a "$LOG_FILE" ;;
        *)         echo -e "${WHITE}[$timestamp] $message${NC}" | tee -a "$LOG_FILE" ;;
    esac
}

# Fonction pour nettoyer les noms (juste les caractères vraiment problématiques)
clean_name() {
    echo "$1" | sed 's/[^a-zA-Z0-9._-]/_/g' | sed 's/__*/_/g'
}

# Détection automatique des vidéos
log "🔍 Recherche des vidéos dans input/"
VIDEO_FILES=()

# Utiliser find (plus robuste que les globs)
while IFS= read -r -d '' file; do
    VIDEO_FILES+=("$file")
done < <(find input -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.mkv" -o -iname "*.wmv" \) -print0 2>/dev/null)

if [ ${#VIDEO_FILES[@]} -eq 0 ]; then
    log "Aucune vidéo trouvée dans input/" "error"
    echo -e "${CYAN}💡 Conseil: Placez vos vidéos (.mp4, .mov, .avi, .mkv, .wmv) dans le dossier input/${NC}"
    echo -e "${WHITE}   Exemple: cp *.mp4 input/${NC}"
    exit 1
fi

echo -e "\n${CYAN}🔍 Analyse terminée !${NC}"
log "${#VIDEO_FILES[@]} vidéo(s) détectée(s)" "success"

# Affichage sympathique de la liste
echo -e "\n${WHITE}📹 Vidéos à traiter:${NC}"
total_size_mb=0
for i in "${!VIDEO_FILES[@]}"; do
    file="${VIDEO_FILES[$i]}"
    name=$(basename "$file")
    size_mb=$(du -m "$file" 2>/dev/null | cut -f1)
    total_size_mb=$((total_size_mb + size_mb))
    estimated_min=$(estimate_duration "$file")
    
    printf "${PURPLE}   %2d.${NC} ${WHITE}%-30s${NC} ${CYAN}(%3dMB ~%2dmin)${NC}\n" $((i+1)) "$name" "$size_mb" "$estimated_min"
done

echo -e "\n${YELLOW}📊 Résumé:${NC}"
echo -e "   ${WHITE}Total:${NC} ${#VIDEO_FILES[@]} vidéos • ${CYAN}${total_size_mb}MB${NC} • ${PURPLE}~$((total_size_mb * 3 / 100))min estimé${NC}"

# Sauvegarde du dossier output original (s'il existe)
if [ -d "output" ] && [ "$(ls -A output 2>/dev/null)" ]; then
    BACKUP_DIR="output_backup_${TIMESTAMP}"
    log "Sauvegarde output existant → $BACKUP_DIR" "warning"
    cp -r output "$BACKUP_DIR"
fi

# Confirmation avant démarrage
echo -e "\n${YELLOW}⚡ Prêt à démarrer le traitement !${NC}"
echo -e "${WHITE}   Appuyez sur ${GREEN}[Entrée]${WHITE} pour continuer ou ${RED}Ctrl+C${WHITE} pour annuler${NC}"
read -r

echo -e "\n${GREEN}🚀 Démarrage du traitement...${NC}\n"

# Variables de statistiques
SUCCESS_COUNT=0
ERROR_COUNT=0
START_TIME=$(date +%s)

# Traitement de chaque vidéo avec monitoring sympathique
for i in "${!VIDEO_FILES[@]}"; do
    VIDEO_FILE="${VIDEO_FILES[$i]}"
    VIDEO_NAME=$(basename "$VIDEO_FILE" | sed 's/\.[^.]*$//')
    CLEAN_NAME=$(clean_name "$VIDEO_NAME")
    CURRENT=$((i + 1))
    TOTAL=${#VIDEO_FILES[@]}
    
    # En-tête de section avec style
    echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║${NC}  🎬 ${WHITE}[$CURRENT/$TOTAL] $VIDEO_NAME${NC} $(printf "%*s" $((50-${#VIDEO_NAME})) "") ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"
    
    # Nettoyer le dossier output pour cette vidéo
    rm -rf output/*
    
    # Copier la vidéo courante
    if cp "$VIDEO_FILE" "input/video.mp4"; then
        log "Préparation: $(basename "$VIDEO_FILE") → video.mp4" "info"
    else
        log "Échec copie de $VIDEO_FILE" "error"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        continue
    fi
    
    # Lancer VOTRE script original avec monitoring
    echo -e "${CYAN}🔄 Traitement en cours...${NC}"
    PROCESS_START=$(date +%s)
    
    # Créer un marqueur pour le monitoring
    touch /tmp/processing_active
    
    # Estimer la durée
    ESTIMATED_MINUTES=$(estimate_duration "$VIDEO_FILE")
    
    # Lancer le monitoring en arrière-plan
    (
        show_progress "Transcription et traduction" $((ESTIMATED_MINUTES * 60))
    ) &
    MONITOR_PID=$!
    
    # Lancer votre script original avec gestion automatique de l'environnement
    if eval "$AUTO_VENV_ACTIVATION timeout $((ESTIMATED_MINUTES * 60 + 300)) ./generate_subtitles.sh" >> "$LOG_FILE" 2>&1; then
        # Arrêter le monitoring
        rm -f /tmp/processing_active
        kill $MONITOR_PID 2>/dev/null || true
        wait $MONITOR_PID 2>/dev/null || true
        
        PROCESS_END=$(date +%s)
        PROCESS_TIME=$((PROCESS_END - PROCESS_START))
        
        printf "\r${GREEN}✅ Traitement terminé en %dm%ds                    ${NC}\n" $((PROCESS_TIME / 60)) $((PROCESS_TIME % 60))
        
        # Créer un dossier dédié pour cette vidéo
        FINAL_OUTPUT_DIR="output_final/$CLEAN_NAME"
        mkdir -p "$FINAL_OUTPUT_DIR"
        
        # Sauvegarder tous les fichiers générés
        if cp -r output/* "$FINAL_OUTPUT_DIR/" 2>/dev/null; then
            log "Fichiers sauvés dans: $FINAL_OUTPUT_DIR/" "success"
            SUCCESS_COUNT=$((SUCCESS_COUNT + 1))
            
            # Vérifier le fichier final avec animation
            if [ -f "$FINAL_OUTPUT_DIR/subtitles_en.vtt" ]; then
                VTT_LINES=$(wc -l < "$FINAL_OUTPUT_DIR/subtitles_en.vtt" 2>/dev/null || echo "0")
                echo -e "${GREEN}   🎯 Fichier VTT généré: $VTT_LINES lignes${NC}"
                
                # Petit effet de validation
                for j in {1..3}; do
                    printf "${GREEN}   ✨${NC}"
                    sleep 0.2
                done
                printf "\n"
            fi
        else
            rm -f /tmp/processing_active
            kill $MONITOR_PID 2>/dev/null || true
            log "Échec sauvegarde des fichiers" "error"
            ERROR_COUNT=$((ERROR_COUNT + 1))
        fi
        
    else
        # Arrêter le monitoring en cas d'erreur
        rm -f /tmp/processing_active
        kill $MONITOR_PID 2>/dev/null || true
        wait $MONITOR_PID 2>/dev/null || true
        
        printf "\r${RED}❌ Échec du traitement                              ${NC}\n"
        log "Échec du script pour $VIDEO_NAME" "error"
        ERROR_COUNT=$((ERROR_COUNT + 1))
        
        # Sauvegarder les logs d'erreur quand même
        ERROR_DIR="output_final/${CLEAN_NAME}_ERROR"
        mkdir -p "$ERROR_DIR"
        cp -r output/* "$ERROR_DIR/" 2>/dev/null || true
        echo "Erreur lors du traitement de $VIDEO_NAME - $(date)" > "$ERROR_DIR/ERROR.txt"
    fi
    
    # Nettoyer pour la prochaine vidéo
    rm -f "input/video.mp4"
    
    # Petit délai pour l'effet visuel
    sleep 0.5
done

# Statistiques finales avec style
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))

echo -e "\n${PURPLE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    🎉 ${WHITE}TRAITEMENT TERMINÉ${NC} 🎉                    ${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════╝${NC}"

# Affichage des stats avec couleurs
echo -e "\n${WHITE}📊 Statistiques finales:${NC}"
echo -e "   ${GREEN}✅ Réussis: $SUCCESS_COUNT/${#VIDEO_FILES[@]}${NC}"
echo -e "   ${RED}❌ Échecs:  $ERROR_COUNT/${#VIDEO_FILES[@]}${NC}"
echo -e "   ${CYAN}⏱️  Temps total: $((TOTAL_TIME / 60))m$((TOTAL_TIME % 60))s${NC}"

# Calcul du taux de réussite
if [ ${#VIDEO_FILES[@]} -gt 0 ]; then
    SUCCESS_RATE=$((SUCCESS_COUNT * 100 / ${#VIDEO_FILES[@]}))
    if [ $SUCCESS_RATE -eq 100 ]; then
        echo -e "   ${GREEN}🏆 Taux de réussite: $SUCCESS_RATE% - PARFAIT !${NC}"
    elif [ $SUCCESS_RATE -ge 80 ]; then
        echo -e "   ${YELLOW}⭐ Taux de réussite: $SUCCESS_RATE% - Très bon !${NC}"
    else
        echo -e "   ${RED}⚠️  Taux de réussite: $SUCCESS_RATE% - À améliorer${NC}"
    fi
fi

echo -e "\n${WHITE}📂 Résultats sauvés dans: ${CYAN}output_final/${NC}"

if [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "\n${GREEN}🎯 Fichiers VTT générés:${NC}"
    find output_final -name "subtitles_en.vtt" -exec echo -e "   ${WHITE}{}${NC}" \;
    
    # Animation de fin réussie
    echo -e "\n${GREEN}"
    for i in {1..3}; do
        printf "✨ "
        sleep 0.3
    done
    echo -e "Traitement multi-vidéos réussi ! ✨${NC}"
fi

log "📋 Log complet: $LOG_FILE"

# Résumé final dans une boîte
echo -e "\n${BLUE}┌─────────────────────────────────────────┐${NC}"
echo -e "${BLUE}│${NC} 🎬 ${WHITE}Traitement multi-vidéos terminé !${NC}     ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} 📂 ${CYAN}Résultats:${NC} output_final/           ${BLUE}│${NC}"
echo -e "${BLUE}│${NC} 📋 ${CYAN}Log:${NC} $LOG_FILE ${BLUE}│${NC}"
echo -e "${BLUE}└─────────────────────────────────────────┘${NC}"

# Nettoyage final
rm -f /tmp/processing_active

