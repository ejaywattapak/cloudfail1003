# EJAYWATT CLOUDFAIL v13.6 - FIX BUNDLE

Bundle v13.6 (revisi 2). Kandungan zip ikut susun atur repo -> copy tampal.

    installer.sh              GANTI  (v13.6, revisi 2)
    setup.sh                  GANTI  (v13.6, revisi 2)
    menu.sh                   GANTI  (dah dipatch: baca modules.list)
    modules.list              BAHARU
    tools/gen_sha256sums.sh   BAHARU
    SHA256SUMS                BAHARU (jana semula jika fail lain berubah)
    APPLY.md                  dokumen ini

## Langkah

    # 1. copy semua fail di atas ke akar repo (kekalkan tools/)
    # 2. bersihkan fail orphan
    printf '__pycache__/\n*.pyc\n*.pyo\n*.zip\n' > .gitignore
    git rm -r --cached __pycache__ 2>/dev/null
    # 3. kalau mana-mana fail .sh lain berbeza dari GitHub main:
    bash tools/gen_sha256sums.sh
    # 4. push SEMUA sekali gus
    git add -A && git commit -m "v13.6: modules.list, SHA256, backup pruning, symlink installer" && git push

Di VPS:

    wget -O installer.sh https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main/installer.sh
    chmod +x installer.sh && ./installer.sh      # pilih [1] atau [2]
    menu                                          # atau: cloudfail-update

## Apa yang dibetulkan (v13.6)

 1. Senarai modul: SATU sumber = modules.list (dulu 3 salinan dalam
    installer.sh / setup.sh / menu.sh). Tambah modul: edit modules.list je.
 2. Sahkan SHA256 (SHA256SUMS) sebelum ganti fail; fail lama dikekalkan
    kalau checksum tak sepadan. Escape hatch: CF_SHA_CHECK=0 ./installer.sh
 3. Backup .bak dihadkan 3 terkini per fail. Tukar: CF_KEEP_BACKUPS=5
 4. installer.sh: SATU salinan rasmi di /usr/local/share/cloudfail1003/.
    Fail yang kau jalankan (contoh ~/installer.sh) ditukar jadi PAUTAN
    (symlink) ke salinan rasmi -> takde lagi 2 salinan berasingan.
    (Revisi 1 cetak 2 baris "installer.sh" sebab ia tulis 2 fail.)
    Arahan baru: cloudfail-update
 5. Option 1 kini juga kemas kini installer.sh sendiri.
 6. Kotak banner SEJAJAR: teks kotak kini ASCII + helper box_row().
    Punca dulu: emoji ⚡ lebar 2 lajur dlm terminal tapi shell kira 1
    aksara, jadi padding kiraan salah. (Bug ni dah ada sejak v13.5.)
 7. Output status dirapatkan (1 baris per fail, <=66 aksara) supaya muat
    terminal sempit (SSH dari telefon):

        [✔] menu/ipclone.sh            OK (http200 bash sha256)
        [✘] menu/history.sh            GAGAL (HTTP 404) - lama dikekalkan

 8. Auto-menu login guna blok bermarker (# >>> cloudfail-automenu >>>).
    Dulu skrip padam SEMUA baris /root/.bashrc yang menyebut
    /usr/bin/menu; kini baris lain selamat.
 9. ROOT_FILES tidak lagi kod mati.

## Yang TIDAK diubah

core.sh, menu/*.sh (modul), more/antick.sh, apply_themes_update.py,
prepare_upload.sh. Tema, sejarah dan logik scanner sama seperti dulu.

## Peringatan

- Bundle ini diuji di Android (mksh) dengan arahan luar dimock:
  17/17 fail OK, SHA salah -> ditolak, HTTP 404 -> fail lama kekal,
  pruning kekal 3, symlink installer dibuat, penjajaran kotak disemak
  (semua baris 56 aksara), .bashrc baris lain terselamat.
- Belum diuji dengan bash + curl + apt + root sebenar. Kalau boleh, uji
  atas VPS staging / snapshot VPS dulu.
