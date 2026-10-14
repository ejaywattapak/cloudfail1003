  // 5. README.md
      zip.file("README.md", `<div align="center">
<img src="https://capsule-render.vercel.app/api?type=waving&color=0:6b21a8,50:0284c7,100:00f2fe&height=230&section=header&text=EJAYWATT%20CLOUDFAIL&fontSize=52&fontColor=ffffff&animation=fadeIn&fontAlignY=38&desc=Multi-Range%20GeoIP%20%26%20Live%20Error%201003%20Scanner&descAlignY=60&descSize=20" width="100%" />
<p>
  <img src="https://img.shields.io/badge/Ubuntu-Latest-E95420?style=for-the-badge&logo=ubuntu&logoColor=white"/>
  <img src="https://img.shields.io/badge/Debian-Latest-A81D33?style=for-the-badge&logo=debian&logoColor=white"/>
  <img src="https://img.shields.io/badge/Rocky_Linux-Latest-10B981?style=for-the-badge&logo=rockylinux&logoColor=white"/>
</p>
<a href="https://t.me/ejwtpkvpn" target="_blank">
  <img src="https://img.shields.io/badge/Contact_Telegram-@ejwtpkvpn-26A5E4?style=for-the-badge&logo=telegram&logoColor=white" height="42"/>
</a>
</div>

## 🚀 One-Line Installer (wget)
\`\`\`bash
wget -O installer.sh https://raw.githubusercontent.com/ejaywattapak/cloudfail1003/main/installer.sh && chmod +x installer.sh && ./installer.sh
\`\`\`

<div align="center">
  <a href="https://t.me/ejwtpkvpn" target="_blank">
    <img src="https://upload.wikimedia.org/wikipedia/commons/8/82/Telegram_logo.svg" width="60"/><br/>
    <b>Contact Telegram: @ejwtpkvpn</b>
  </a>
</div>
`);

      const content = await zip.generateAsync({ type: "blob" });
      const a = document.createElement("a");
      a.href = URL.createObjectURL(content);
      a.download = "cloudfail1003.zip";
      a.click();
    }
  </script>
</body>
</html>
