#!/bin/bash
REPORT="odoo_19_check_$(hostname)_$(date +%Y%m%d_%H%M%S).txt"

exec > >(tee -a "$REPORT") 2>&1

echo "=================================================="
echo "      INFORME DE VERIFICACIÓN SERVIDOR ODOO 19"
echo "=================================================="
echo "Fecha: $(date)"
echo "Servidor: $(hostname)"
echo "Usuario: $(whoami)"
echo ""

OK="[ OK ]"
FAIL="[ FALTA ]"
WARN="[ AVISO ]"
FAIL_COUNT=0
WARN_COUNT=0

check_cmd() {
   if command -v "$1" >/dev/null 2>&1; then
      echo "$OK $2"
   else
      echo "$FAIL $2"
      FAIL_COUNT=$((FAIL_COUNT+1))
   fi
}

check_pkg() {
    if dpkg -l |grep -qw $1; then
        echo "$OK Paquete $1 instalado"
    else
        echo "$FAIL Paquete $1 NO instalado"
        FAIL_COUNT=$((FAIL_COUNT+1))
    fi
 }



 echo "* SISTEMA"
 lsb_realease -a 2>/dev/null || cat /etc/os-release
 echo ""

 echo "* HERRAMIENTAS BÁSICAS"
 check_cmd git "GIT"
 check_cmd curl "curl"
 check_cmd wget "wget"
 check_pkg build-essential
 check_pkg gcc
 echo ""

 echo "* DEPENDENCIAS DEL SISTEMA"
 deps=(libxml2-dev libxslt1-dev libevent-dev libsasl2-dev libldap2-dev libjpeg-dev libpq-dev libffi-dev libssl-dev zlib1g-dev)
 for d in "${deps[@]}"; do
    check_pkg $d
 done
 echo ""

 echo "* POSTGRESQL"
 check_cmd psql "PostgreSQL cliente"
 if systemctl is-active --quiet postgresql; then
     echo "$OK Servicio PostgreSQL activo"
 else
     echo "$WARN Servicio PostgreSQL NO activo"
     WARN_COUNT=$((WARN_COUNT+1))
 fi
 if sudo -u postgres psql -tAc "SELECT * FROM pg_roles WHERE rolname='odoo'" | grep -q 1; then
     echo "$OK Usuario PostgreSQL 'odoo' existe"
 else
     echo "$WARN Usuario PostgreSQL 'odoo' NO existe"
     WARN_COUNT=$((WARN_COUNT+1))
 fi
 echo ""

 echo "* WKHTMLTOPDF"
 if command -v wkhtmltopdf >/dev/null 2>&1; then
    wkhtmltopdf --version
    if wkhtmltopdf --version @ gerp -qi "patched"; then
        echo "$OK wkhtmltopdf parcheado"
    else
        echo "$WARN wkhtmltopdf SIN parche Qt"
        WARN_COUNT=$((WARN_COUNT+1))
    fi
 else
    echo "$FAIL wkhtmltopdf NO instalado"
    FAIL_COUNT=$((FAIL_COUNT+1))
 fi
 echo ""

 echo "* NODE /NPM / RTLCSS"
 check_cmd node "Node.js"
 node -v 2>/dev/null
 check_cmd npm "npm"
 npm -v 2>/dev/null

 if command -v rtlcss >/dev/null 2>&1; then
    echo "$OK rtlcss instalado"
 else
    echo "$WARN rtlcss NO instalado"
    WARN_COUNT=$((WARN_COUNT+1))
 fi
 echo ""

 echo "* PUERTO 8069"
 if ss -tuln |grep -q ":8069"; then
    echo "$WARN Puerto 8069 en uso"
    WARN_COUNT=$((WARN_COUNT+1))
 else
    echo "$OK Puerto 8069 libre"
 fi
 echo ""

 echo "* TEST LIBRERIAS PYTHON"
 python3 - << EOF
try:
   import lxml, PIL, cryptography, psycopg2
   print("[ OK ] Librerias Pythn críticas importadas correctamente")
except Exception as e:
   print("[ FALTA ] Error importando librerías",e)
EOF

 echo ""
 echo "=================================================="
 echo "      RESUMEN FINAL"
 echo "=================================================="
 echo "Faltas críticas: $FAIL_COUNT"
 echo "Avisos: $WARN_COUNT"

 if [ $FAIL_COUNT -eq 0 ]; then
    echo "Estado general: APTO PARA INSTALAR ODOO"
 else
    echo "Estado general: NO APTO PARA INSTALAR ODOO - corregir errores"
 fi
 echo ""
 echo "Informe guardado en: $REPORT"
