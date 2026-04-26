# 🔍 Linux Credential Hunter

![Bash](https://img.shields.io/badge/language-Bash-4EAA25?style=flat-square&logo=gnubash&logoColor=white)
![ShellCheck](https://img.shields.io/badge/ShellCheck-passing-brightgreen?style=flat-square)
![Platform](https://img.shields.io/badge/platform-Linux-lightgrey?style=flat-square&logo=linux)

---

## Nima uchun bu script kerak?

Linux tizimiga dastlabki kirish huquqiga ega bo'lgandan so'ng — masalan, zaif web ilova orqali reverse shell olganingizda — keyingi qadam **imtiyozlarni oshirishdir (privilege escalation)**. Buning eng tez va samarali yo'li: tizimda allaqachon saqlanib yotgan **parollar, tokenlar, SSH kalitlar va ma'lumotlar bazasi kredensiallarini** topishdir.

Muammo shundaki, bu ma'lumotlar tizimning turli burchaklarida yashiringan bo'ladi — konfiguratsiya fayllari, skriptlar, bash tarixi, muhit o'zgaruvchilari, brauzer saqlangan parollar va boshqalar. Ularni qo'lda birma-bir qidirish vaqt talab qiladi va ko'p narsani o'tkazib yuborish xavfi bor.

`cred_hunt.sh` shu jarayonni **avtomatlashtiradi**: bitta buyruq bilan tizimning barcha asosiy joylarini skanerlaydi va topilgan narsalarni tartibli fayllarga saqlaydi.

---

## Bu script nima qiladi?

Script **12 ta mustaqil modul** orqali ishlaydi. Har bir modul ma'lum bir toifani tekshiradi:

| # | Modul | Nima izlaydi |
|---|-------|-------------|
| 01 | **Konfiguratsiya fayllari** | `.conf` `.config` `.cnf` — `password`, `token`, `secret` kalit so'zlarini qidiradi |
| 02 | **Ma'lumotlar bazalari** | `.sql`, `.db` fayllarini topadi |
| 03 | **Eslatmalar** | `/home` ichidagi `.txt` va kengaytmasiz fayllar |
| 04 | **Skriptlar** | `.py` `.sh` `.php` `.go` `.rb` — hardcoded parollarni qidiradi |
| 05 | **Cronjob'lar** | `/etc/cron.*` va foydalanuvchi crontab'lari |
| 06 | **SSH kalitlar** | `id_rsa`, `.pem`, `authorized_keys` fayllarini topadi |
| 07 | **Shell tarixi** | `.bash_history`, `.zsh_history` — CLI orqali yozilgan parollar |
| 08 | **Log fayllar** | `auth.log`, `nginx`, `apache`, `mysql` — login urinishlari |
| 09 | **Muhit o'zgaruvchilari** | `env` + `/proc/*/environ` — jarayon xotirasidagi secretlar |
| 10 | **Brauzer** | Firefox `key4.db` / `logins.json`, Chrome `Login Data` |
| 11 | **passwd / shadow** | Login qila oladigan userlar, parol hashlari |
| 12 | **World-readable fayllar** | Hamma o'qiy oladigan maxfiy fayllar |

Har bir modul topilgan narsani terminalga `[+]` bilan chiqaradi va natijalarni `cred_results_<sana>/` papkasiga saqlaydi.

---

## Ishlatish

```bash
chmod +x cred_hunt.sh

# Barcha 12 modul (to'liq skan)
sudo ./cred_hunt.sh

# Tezkor skan — faqat 4 ta asosiy modul
sudo ./cred_hunt.sh quick
```

---

## Kimlar uchun?

- **CTF / HackTheBox / TryHackMe** ishtirokchilari — post-exploitation bosqichida vaqtni tejash uchun
- **Penetration testerlar** — authorized engagement'larda credential enumeration'ni avtomatlashtirish uchun
- **Xavfsizlik talabalari** — Linux tizimida parollar qayerlarda saqlanishini amalda o'rganish uchun

---

## ⚠️ Muhim

Bu tool faqat **o'z tizimingizda yoki yozma ruxsat mavjud bo'lgan tizimlarда** ishlatish uchun mo'ljallangan. Ruxsatsiz tizimda ishlatish qonunga xilofdir.

