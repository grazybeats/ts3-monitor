#!/usr/bin/env bash
# ============================================================
# cleanup_once.sh
# Einmalige manuelle Bereinigung: behält nur die letzten N Runs
# Voraussetzung: GitHub CLI (gh) installiert + eingeloggt
# Aufruf: bash cleanup_once.sh [ANZAHL_BEHALTEN] [--dry-run]
# ============================================================

set -euo pipefail

REPO="grazybeats/ts3-monitor"
WORKFLOW="main.yml"
KEEP="${1:-5}"          # Standard: 5 behalten
DRY_RUN=false
[[ "${2:-}" == "--dry-run" ]] && DRY_RUN=true

# Farben
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${BLUE}  GitHub Actions Run Cleanup${NC}"
echo -e "${BLUE}  Repo:     ${REPO}${NC}"
echo -e "${BLUE}  Workflow: ${WORKFLOW}${NC}"
echo -e "${BLUE}  Behalten: ${KEEP} Runs${NC}"
echo -e "${BLUE}  Dry-Run:  ${DRY_RUN}${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"

# Prüfen ob gh installiert ist
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Fehler: GitHub CLI (gh) ist nicht installiert.${NC}"
    echo "Installation: https://cli.github.com/"
    exit 1
fi

# Prüfen ob eingeloggt
if ! gh auth status &> /dev/null; then
    echo -e "${RED}Fehler: Nicht eingeloggt. Bitte 'gh auth login' ausführen.${NC}"
    exit 1
fi

echo ""
echo "Abrufen aller completed Runs..."

# Alle completed Run-IDs abrufen (neueste zuerst, paginiert)
# format: ID DATUM RUN_NUMBER CONCLUSION
ALL_RUNS=$(gh api --paginate \
    "/repos/${REPO}/actions/workflows/${WORKFLOW}/runs?status=completed&per_page=100" \
    --jq '.workflow_runs[] | "\(.id) \(.created_at) \(.run_number) \(.conclusion)"' \
    | sort -k2 -r)   # nach Datum sortieren, neueste zuerst

TOTAL=$(echo "$ALL_RUNS" | grep -c "" || true)
echo -e "Gefunden: ${TOTAL} completed Runs"

if [[ $TOTAL -le $KEEP ]]; then
    echo -e "${GREEN}✅ Nichts zu tun – nur ${TOTAL} Runs vorhanden (≤ ${KEEP}).${NC}"
    exit 0
fi

# Zu behaltende Runs (erste KEEP Zeilen)
KEEP_RUNS=$(echo "$ALL_RUNS" | head -n "$KEEP")
echo ""
echo -e "${GREEN}Behalte folgende ${KEEP} Runs:${NC}"
while IFS=' ' read -r id date rnum conclusion; do
    echo -e "  ${GREEN}✅ Run #${rnum}${NC} (ID: ${id}) | ${date} | ${conclusion}"
done <<< "$KEEP_RUNS"

# Zu löschende Runs (alles nach KEEP)
TO_DELETE=$(echo "$ALL_RUNS" | tail -n +$((KEEP + 1)))
DELETE_COUNT=$(echo "$TO_DELETE" | grep -c "" || true)
echo ""
echo -e "${YELLOW}Zu löschen: ${DELETE_COUNT} Runs${NC}"

if [[ "$DRY_RUN" == "true" ]]; then
    echo -e "${YELLOW}[DRY-RUN] Folgende Runs würden gelöscht:${NC}"
    while IFS=' ' read -r id date rnum conclusion; do
        echo -e "  ${YELLOW}🗑️  Run #${rnum}${NC} (ID: ${id}) | ${date} | ${conclusion}"
    done <<< "$TO_DELETE"
    echo ""
    echo -e "${YELLOW}Dry-Run abgeschlossen. Kein Eintrag wurde gelöscht.${NC}"
    echo "Zum echten Löschen: bash cleanup_once.sh ${KEEP}"
    exit 0
fi

# Sicherheitsabfrage
echo ""
echo -e "${RED}⚠️  ${DELETE_COUNT} Workflow-Runs werden unwiderruflich gelöscht!${NC}"
read -rp "Fortfahren? (ja/nein): " CONFIRM
if [[ "$CONFIRM" != "ja" ]]; then
    echo "Abgebrochen."
    exit 0
fi

# Löschen
DELETED=0; FAILED=0
while IFS=' ' read -r id date rnum conclusion; do
    echo -ne "  Lösche Run #${rnum} (ID: ${id})... "
    if gh api -X DELETE "/repos/${REPO}/actions/runs/${id}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC}"
        ((DELETED++))
    else
        echo -e "${RED}✗ Fehler${NC}"
        ((FAILED++))
    fi
    sleep 0.3   # Rate-Limit: max ~200 Requests/min
done <<< "$TO_DELETE"

echo ""
echo -e "${BLUE}══════════════════════════════════════${NC}"
echo -e "${GREEN}  Gelöscht:    ${DELETED}${NC}"
[[ $FAILED -gt 0 ]] && echo -e "${RED}  Fehler:      ${FAILED}${NC}"
echo -e "${GREEN}  Verbleibend: ${KEEP} Runs${NC}"
echo -e "${BLUE}══════════════════════════════════════${NC}"
