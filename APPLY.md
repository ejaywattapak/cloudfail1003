# EJAYWATT CLOUDFAIL v13.6 - FIX BUNDLE

Tarikh: bundle ini mengandungi fail yang telah dibetulkan (v13.5 -> v13.6).
Kandungan zip mengikut susun atur repo. Copy tampal ke akar repo:

    installer.sh              (GANTI - versi baru)
    setup.sh                  (GANTI - versi baru)
    menu.sh                   (GANTI - sudah dipatch: baca modules.list)
    modules.list              (BAHARU)
    tools/gen_sha256sums.sh   (BAHARU)
    SHA256SUMS                (BAHARU - jana semula jika fail lain berubah)
    APPLY.md                  (dokumen ini, tak perlu commit)

## Langkah

    # 1. copy semua fail di atas ke akar repo (kekalkan tools/)

    # 2. bersihkan fail orphan
    printf '__pycache__/\n*.pyc\n*.pyo\n*.zip\n' > .gitignore
    git rm -r --cached __pycache__ 2>/dev/null

    # 3. PENTING: kalau mana-mana fail .sh dalam repo kau berbeza dari
    #    GitHub HEAD, jana semula checksum:
    bash tools/gen_sha256sums.sh

    # 4. push SEMUA sekali gus (installer/setup/menu/modules.list/SHA256SUMS)
    git add -A
    git commit -m "v13.6: modules.list, SHA256 verify, backup pruning, installer self-update"
    git push

Lepas push, di VPS:

    wget -O installer.sh https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main/installer.sh
    chmod +x installer.sh && ./installer.sh     # pilih [1] atau [2]
    menu                                        # atau: cloudfail-update

## Apa yang dibetulkan

1. Senarai modul: dulu 3 salinan (installer.sh / setup.sh / menu.sh).
   Kini SATU sumber = modules.list (ada fallback dalam setiap fail).
   Tambah modul baru: edit modules.list sahaja.
2. Sahkan SHA256 (SHA256SUMS) sebelum ganti fail - fail lama dikekalkan
   kalau checksum tak sepadan.
   AMARAN: kalau edit .sh tapi tak regenerate SHA256SUMS, update fail itu
   akan DITOLAK. Escape hatch: CF_SHA_CHECK=0 ./installer.sh
3. Backup .bak dihadkan kepada 3 terkini per fail (dulu menimbun).
   Tukar: CF_KEEP_BACKUPS=5 ./installer.sh
4. installer.sh kini dipasang ke /usr/local/share/cloudfail1003/installer.sh,
   self-update pada Option 1 DAN 2, dan ada arahan baru: cloudfail-update.
5. Option 1 kini juga kemas kini installer.sh sendiri (dulu tak).
6. Kotak menu installer.sh kini sejajar (guna menu_row/menu_title_row).
7. Auto-menu login guna blok bermarker (# >>> cloudfail-automenu >>>).
   Versi lama padam SEMUA baris /root/.bashrc yang menyebut /usr/bin/menu -
   kini baris lain selamat. Buang blok: padam antara marker.
8. ROOT_FILES tidak lagi kod mati.

## Yang TIDAK diubah

core.sh, menu/*.sh (modul), more/antick.sh, apply_themes_update.py,
prepare_upload.sh. Tema, sejarah dan logik scanner sama seperti dulu.

## Kalau guna prepare_upload.sh

Tambah dalam senarai `files` di dalam prepare_upload.sh:
    "modules.list", "SHA256SUMS"
Dan sebelum langkah zip, jana checksum dalam repo klon:
    ( cd "$WORKDIR/repo" && sha256sum installer.sh setup.sh core.sh menu.sh \
        modules.list menu/*.sh more/antick.sh > SHA256SUMS )

## Peringatan

- Bundle ini diuji atas Android (mksh) dengan arahan luar dimock: happy path
  17/17 UPDATED, SHA salah -> ditolak, HTTP 404 -> fail lama kekal,
  pruning backup kekal 3, .bashrc baris lain terselamat.
- Belum diuji dengan bash sebenar + curl + apt + root. Uji atas VPS staging
  dulu kalau boleh (atau guna snapshot VPS).
- Semua construct yang digunakan lebih ringkas dari fail v13.5 kau
  (tiada <(...), tiada [[ ]]), jadi risiko bash rendah.
