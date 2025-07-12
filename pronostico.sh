#!/bin/bash
# -----------------------------------------------------------------------------
# ARCHIVO:      pronostico.sh (Revisado)
#
# TÍTULO:       Script Conductor para el Pronóstico de Emisiones
# VERSIÓN:      2.0
# FECHA:        12/07/2024
# AUTOR:        "Jose Agustin Garcia Reynoso" <agustin@atmosfera.unam.mx>
# REVISIÓN:     Gemini
#
# DESCRIPCIÓN:  Este script orquesta el cálculo del inventario de emisiones
#               para un pronóstico de 3 días (hoy, mañana y pasado mañana).
#               Se encarga de la configuración inicial, la limpieza de
#               archivos antiguos y la ejecución del procesamiento diario.
#
# USO:          ./pronostico.sh
# -----------------------------------------------------------------------------

# =============================================================================
# SECCIÓN DE CONFIGURACIÓN DE USUARIO
# Modifique estas variables para ajustar el comportamiento del script.
# =============================================================================

# 1. Dominio de modelado.
#    Dominios disponibles: bajio bajio3 cdjuarez   colima    ecacor  ecaim ecaim3
#   guadalajara  jalisco    mexicali  mexico  mexico9
#   monterrey    monterrey3 queretaro tijuana
dominio=tijuana
# Se ubica en el directorio de trabajo
# 
DOMAINS=/LUSTRE/ID/FQA/agustin/emis_2018

# 2. Mecanismo químico a utilizar.
#    Mecanismos disponibles: cbm04, cbm05, mozart, racm2, radm2, saprc99, saprc07, ghg
MECHA=radm2

# 3. Selección de modelo de calidad del aire (solo si MECHA=saprc07).
#    0 = WRF-Chem, 1 = CHIMERE
AQM_SELECT=0

# 4. Número de archivos de salida por día.
#    1 = Un archivo de 24 horas.
#    2 = Dos archivos de 12 horas.
nfile=2

# 5. Forzar la recreación de la distribución espacial (1=Sí, 0=No).
#    Poner en 1 la primera vez que se corre para un dominio o si hay cambios
#    en los datos de entrada de la distribución.
HacerArea=0

#####  FIN DE LAS MODIFICACIONES DE USUARIO  #####

# --- Cargar la biblioteca de funciones ---
# Asegúrate de que el archivo functions.sh esté en el mismo directorio.
if [ ! -f "functions.sh" ]; then
    echo "ERROR: No se encuentra el archivo 'functions.sh'. Abortando."
    exit 1
fi
source functions.sh

# --- Exportar variables para que sean visibles en las funciones ---
export dominio MECHA AQM_SELECT nfile HacerArea

# =============================================================================
# INICIO DEL SCRIPT PRINCIPAL
# =============================================================================

# 1. Verificar que el directorio del dominio exista.
check_domain

# 2. Preparar el directorio de trabajo temporal.
#    Esta sección crea el directorio 'tmp<dominio>' si no existe y ejecuta
#    la distribución espacial (un proceso costoso) solo si es necesario.
TMP_DIR="tmp${dominio}"
if [ ! -d "$TMP_DIR" ]; then
    echo -e "${COLOR_INFO}Directorio '$TMP_DIR' no existe. Creándolo por primera vez...${COLOR_RESET}"
    export HacerArea=1 # Forzar la distribución espacial en la primera ejecución
    make_tmpdir "$TMP_DIR"
    echo -e "${COLOR_INFO}Ejecutando distribución espacial (puede tardar)...${COLOR_RESET}"
    export dia=01
    export mes=01
    export nyear=2018
    hace_namelist # Crea el namelist para la distribución
    if [ $HacerArea -ne 0 ]; then
    hace_area &
    hace_movil
    wait
    export HacerArea=0 # Resetear la variable para no repetir el proceso
    echo -e "${COLOR_SUCCESS}Distribución espacial completada.${COLOR_RESET}"
    fi
else
    echo "Directorio de trabajo '$TMP_DIR' ya existe. Entrando..."
    cd "$TMP_DIR"
    # Limpiar directorios de días anteriores para evitar acumulación
    rm -rf dia*
fi


# 3. Limpiar archivos de pronóstico del día de ayer.
echo -e "${COLOR_INFO}Limpiando archivos de pronóstico de días anteriores...${COLOR_RESET}"
limpiar_archivos_viejos

# 4. Bucle principal de procesamiento de pronóstico.
#    Itera para hoy (0), mañana (1) y pasado mañana (2).
echo -e "\n${COLOR_INFO}=====================================================${COLOR_RESET}"
echo -e "${COLOR_INFO}   INICIANDO PROCESAMIENTO DE EMISIONES (3 DÍAS)   ${COLOR_RESET}"
echo -e "${COLOR_INFO}=====================================================${COLOR_RESET}"

for offset in 0 1 2; do
    procesar_dia_pronostico "$offset"
done

# --- Finalización ---
echo -e "\n${COLOR_SUCCESS}=====================================================${COLOR_RESET}"
echo -e "${COLOR_SUCCESS}  PRONÓSTICO DE EMISIONES FINALIZADO EXITOSAMENTE  ${COLOR_SUCCESS}"
echo -e "${COLOR_SUCCESS}=====================================================${COLOR_RESET}"

exit 0
