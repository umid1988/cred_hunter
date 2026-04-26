# 🔐 Linux PE Sensitive Data Hunter

![Bash](https://img.shields.io/badge/language-Bash-4EAA25?style=flat-square&logo=gnubash)
![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey?style=flat-square&logo=linux)

Linux tizimida **Privilege Escalation (PE)** uchun kerakli bo'lgan barcha sensitive ma'lumotlarni topuvchi Bash skripti.
<img width="1439" height="471" alt="image" src="https://github.com/user-attachments/assets/efd51e3b-802a-46f2-b3b2-43061290ed16" />

---

## Nima uchun bu script kerak?

Linux tizimiga kirish huquqiga ega bo'lganingizdan so'ng, keyingi maqsad — **root huquqiga chiqish**. Buning eng tez yo'li: tizimda allaqachon mavjud bo'lgan zaifliklarni va yashiringan ma'lumotlarni topish.

Muammo shundaki, PE uchun kerakli narsalar tizimning turli joylarida tarqalib yotadi va ularni qo'lda birma-bir izlash ko'p vaqt oladi. Bu script **faqat PE uchun haqiqatan muhim bo'lgan narsalarni** qidiradi — ortiqcha shovqinsiz, to'g'ridan-to'g'ri natija.

---

## Nima topadi?

Script **8 ta modul** orqali ishlaydi. Har bir topilma xavf darajasiga qarab belgilanadi:

```
[!!!]  Qizil   →  Darhol foydalanish mumkin bo'lgan zaiflik
[>>]   Sariq   →  Tekshirib ko'rish kerak
```

### Modullar

**1. Joriy foydalanuvchi**
Kim ekanligingizni va qaysi guruhlarda turganingizni tekshiradi.
`docker`, `lxd`, `sudo`, `disk`, `shadow` guruhlarida bo'lsangiz — bu yagona o'zi root olish uchun yetarli.

**2. Sudo huquqlari**
`sudo -l` orqali qaysi buyruqlarni parolsiz (`NOPASSWD`) ishlatish mumkinligini topadi.
Topilgan buyruqlarni GTFOBins'dagi PE usullari bilan taqqoslaydi.
Bu — PE'ning eng tez va samarali yo'li.

**3. SUID / SGID binaries**
Tizimda standart bo'lmagan SUID bitli fayllarni topadi.
Bunday fayllar root sifatida ishlaydi — noto'g'ri konfiguratsiyada shell berishi mumkin.

**4. Linux Capabilities**
SUID alternativasi bo'lgan `cap_setuid`, `cap_net_raw`, `cap_dac_override` kabi
xavfli imtiyozlarga ega fayllarni topadi.

**5. Yozish mumkin bo'lgan muhim fayllar**
Quyidagilarni tekshiradi:
- `/etc/passwd` — yozish mumkin bo'lsa, yangi root user qo'shish mumkin
- `/etc/shadow` — o'qish mumkin bo'lsa, parol hashlari ko'rinadi
- `/etc/sudoers` — yozish mumkin bo'lsa, to'liq sudo berish mumkin
- Root cron'lari chaqiradigan skriptlar — yozish mumkin bo'lsa, root kodingizni ishlatadi
- `$PATH` ichidagi yozish mumkin papkalar — PATH hijacking uchun

**6. Parollar va secretlar**
Faqat muhim joylarda (`/etc`, `/opt`, `/var/www`, `/home`) qidiradi:
- `.env`, `wp-config.php`, `config.php`, `database.yml`, `settings.py` va boshqalar
- `password =`, `db_pass =`, `api_key =` kabi real yozuvlar (sharhlar va placeholder'lar o'tkazib yuboriladi)
- Bash tarixidagi `mysql -p`, `sshpass`, `curl -u` kabi buyruqlar
- Muhit o'zgaruvchilari: `DATABASE_URL`, `AWS_SECRET_ACCESS_KEY` va boshqalar

**7. SSH private kalitlar**
Barcha SSH kalitlarini topadi va passphrasesiz kalitlarni alohida belgilaydi.
Passphrasesiz kalit — boshqa serverga bevosita kirish demak.

**8. Qo'shimcha vektorlar**
- Docker socket (`/var/run/docker.sock`) — container orqali root
- NFS `no_root_squash` — masofadan root mount
- Library hijacking uchun yozish mumkin `ld.so.conf.d` fayllar
- 777 ruxsatli muhim fayllar

---

## Ishlatish

```bash
chmod +x pe_hunt.sh
bash pe_hunt.sh
```

Natijalar terminalga chiqadi va `pe_results_<sana>.txt` fayliga saqlanadi.

---

## ⚠️ Muhim

Bu tool faqat **o'z tizimingizda yoki yozma ruxsat mavjud bo'lgan tizimlarда** ishlatish uchun mo'ljallangan.
