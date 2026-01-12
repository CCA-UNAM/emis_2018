#!/bin/bash
# -----------------------------------------------------------------------------
# ARCHIVO:      functions.sh (Revisado con nuevas funciones)
#
# DESCRIPCIÓN:  Biblioteca de funciones de shell para procesar emisiones.
#               Incluye una función para verificar la salida de cada programa
#               y detener la ejecución en caso de error.
# -----------------------------------------------------------------------------

# --- Definición de Códigos de Color ---
COLOR_INFO='\033[0;36m'
COLOR_SUCCESS='\033[0;32m'
COLOR_WARNING='\033[1;33m'
COLOR_ERROR='\033[1;41m'
COLOR_RESET='\033[0m'

# =============================================================================
# FUNCIÓN: run_and_check (NUEVA)
#
# Propósito:   Ejecuta un comando y verifica su código de salida. Si el código
#              no es 0 (error), imprime un mensaje y aborta el script.
# Parámetros:
#   $@:        El comando completo a ejecutar (ej. bin/ASpatial.exe).
# =============================================================================
run_and_check() {
    # Ejecuta todos los argumentos pasados como un solo comando.
    "$@"
    local exit_code=$? # Captura el código de salida del comando anterior.
    
    if [ $exit_code -ne 0 ]; then
        echo -e "${COLOR_ERROR}ERROR: El comando '$*' falló con el código de salida $exit_code. Abortando.${COLOR_RESET}"
        # Salir del script con el mismo código de error del programa que falló.
        exit $exit_code
    fi
}

# =============================================================================
# BLOQUE DE FUNCIONES DE PROCESAMIENTO (ACTUALIZADO)
#
# Propósito:   Funciones que ejecutan los binarios. Ahora usan 'run_and_check'
#              para garantizar que el script se detenga si un paso falla.
#              La ejecución ahora es secuencial para permitir esta verificación.
# =============================================================================
hace_area() {
    echo "Ejecutando distribución espacial para fuentes de área..."
    run_and_check bin/ASpatial.exe > ./area.log
}

hace_movil() {
    echo "Ejecutando distribución espacial para fuentes móviles..."
    run_and_check bin/vial.exe > ./movil.log
    run_and_check bin/carr.exe >> ./movil.log
    run_and_check bin/agrega.exe >> ./movil.log
    run_and_check bin/MSpatial.exe >> ./movil.log
}

emis_area() {
    echo "Procesando emisiones de ÁREA (Temporal y Especiación)..."
    ln -fs ../chem/profile_${MECHA}.csv .
    run_and_check ../bin/Atemporal.exe > ../area.log
    run_and_check ../bin/spm25a.exe >> ../area.log
    run_and_check ../bin/spa.exe >> ../area.log
}

emis_fijas() {
    echo "Procesando emisiones de FUENTES FIJAS (Temporal y Especiación)..."
    run_and_check ../bin/Puntual.exe > ../puntual.log
    run_and_check ../bin/spm25p.exe >> ../puntual.log
    run_and_check ../bin/spp.exe >> ../puntual.log
}

emis_movil() {
    echo "Procesando emisiones MÓVILES (Temporal y Especiación)..."
    run_and_check ../bin/Mtemporal.exe > ../movil.log
    run_and_check ../bin/spm25m.exe >> ../movil.log
    run_and_check ../bin/spm.exe >> ../movil.log
}

# =============================================================================
# FUNCIÓN: procesar_dia_pronostico
#
# Propósito:   Encapsula la lógica para procesar un día. Ahora las llamadas
#              a emis_* son secuenciales y seguras.
# =============================================================================
procesar_dia_pronostico() {
    local offset="$1"
    local etiqueta_dia
    case $offset in
        0) etiqueta_dia="Hoy";;
        1) etiqueta_dia="Mañana";;
        2) etiqueta_dia="Pasado Mañana";;
        *) echo "Offset inválido"; return;;
    esac

    export dia=$(date -d "+$offset days" +%d)
    export mes=$(date -d "+$offset days" +%m)
    export nyear=$(date -d "+$offset days" +%Y)
    
    local fecha_str="${nyear}-${mes}-${dia}"
    echo -e "\n${COLOR_INFO}--- Procesando día: $etiqueta_dia ($fecha_str) ---${COLOR_RESET}"

    local archivo_salida="${DOMAINS}/interpolaD01/wrfchemi_d01_${MECHA}_${dominio:0:8}_${fecha_str}_00:00:00"
    if [ -f "$archivo_salida" ]; then
        echo -e "${COLOR_WARNING}---> Archivo de salida ya existe. Saltando día.${COLOR_RESET}"
        return
    fi
    
    local dir_dia="dia${dia}"
    mkdir -p "$dir_dia"
    cd "$dir_dia"
    
    echo "Directorio de trabajo: $(pwd)"
    echo "Creando archivos de configuración para el ${dia}/${mes}/${nyear}..."
    hace_namelist
    crea_anio_csv "$nyear" "$mes" "$dia"
    
    echo "Ejecutando procesamiento de emisiones (secuencialmente)..."
    # Estas funciones ahora se detendrán si hay un error interno.
    emis_area
    emis_fijas
    emis_movil
    
    echo "Combinando emisiones y generando archivo final..."
    ln -fs ../chem/namelist.* .
    run_and_check ../bin/emiss.exe > ../${MECHA}_${dia}.log
    
    local inv_dir="../../inventario/${dominio}"
    mkdir -p "$inv_dir"
    mv ./*00:00 "$inv_dir/"
    
    echo -e "${COLOR_SUCCESS}---> Día $etiqueta_dia procesado exitosamente.${COLOR_RESET}"
    cd ..
}


# =============================================================================
# OTRAS FUNCIONES (sin cambios)
# =============================================================================
check_domain() {
    echo -e "${COLOR_INFO}      ___  _ ___ _____ ___   ${COLOR_RESET}"
    echo -e "${COLOR_INFO}     |   \\(_) __|_   _| __|  ${COLOR_RESET}"
    echo -e "${COLOR_INFO}     | |) | | _|  | | | _|   ${COLOR_RESET}"
    echo -e "${COLOR_INFO}     |___/|_|___| |_| |___|  ${COLOR_RESET}"
    echo
    local domain_path="01_datos/$dominio"
    if [ -d "$domain_path" ]; then
        echo -e "${COLOR_SUCCESS}---> Dominio '$dominio' encontrado. Continuando...${COLOR_RESET}"
    else
        echo -e "${COLOR_ERROR} ERROR: El dominio '$dominio' no existe en '01_datos/'. ${COLOR_RESET}"
        exit 1
    fi
}

make_tmpdir() {
    local dir_name="$1"
    if [ -z "$dir_name" ]; then
        echo -e "${COLOR_ERROR} ERROR (make_tmpdir): No se proporcionó un nombre de directorio. ${COLOR_RESET}"
        exit 1
    fi
    if [ -d "$dir_name" ]; then
        if [ "$HacerArea" -eq 1 ]; then
            echo -e "${COLOR_WARNING}Directorio '$dir_name' existe. Eliminando y recreando...${COLOR_RESET}"
            rm -rf "$dir_name"
            mkdir -p "$dir_name"
        fi
    else
        echo "Creando directorio '$dir_name'..."
        mkdir -p "$dir_name"
    fi
    cd "$dir_name"
    echo "Cambiado al directorio de trabajo: $(pwd)"
    ln -fs ../01_datos/"$dominio" .
    ln -fs ../01_datos/chem .
    ln -fs ../01_datos/time .
    ln -fs ../01_datos/emis .
    ln -fs ../bin .
}

crea_anio_csv() {
    local anio mes dia fecha
    if [ $# -eq 3 ]; then
        anio="$1"; mes="$2"; dia="$3"
        fecha="$anio/$mes/$dia"
        # Validar si la fecha es correcta
        if ! date -d"$fecha" &>/dev/null; then
            echo -e "${COLOR_ERROR} ERROR: La fecha '$fecha' no es válida. ${COLOR_RESET}"; exit 1
        fi
        
        # Obtener el día de la semana (0=Domingo, 1=Lunes, ..., 6=Sábado)
        local dow=$(date -d"$fecha" "+%w")
        
        # Si es Domingo (0), cambiar su valor a 7 como se requiere.
        if [ "$dow" -eq 0 ]; then
            dow=6
        fi
        
        # Obtener el resto de los componentes de la fecha
        local mes_csv=$(date -d"$fecha" "+%m")
        local dia_csv=$(date -d"$fecha" "+%d")
        local nomdia_csv=$(date -d"$fecha" "+%a")

        # Reconstruir la línea con el día de la semana corregido (formato: mes,dia,n_dia_semana,nomdia_semana)
        local linea="${mes_csv},${dia_csv},${dow},${nomdia_csv}"
        
        local csv_file="anio${anio}.csv"
        echo "mes,dia,n_dia_semana,nomdia_semana" > "$csv_file"
        echo "$linea" >> "$csv_file"
        mv "$csv_file" ../time/
    else
        echo -e "${COLOR_ERROR} USO INCORRECTO: crea_anio_csv AAAA MM DD ${COLOR_RESET}"; exit 1
    fi
}

hace_namelist() {
    cat > namelist_emis.nml <<- End_Of_File
	!
	!   Definicion de variables para calculo del Inventario
	!
	&region_nml
	zona ="$dominio"
	/
	&fecha_nml
	idia=$dia
	month=$mes
	anio=$nyear
	periodo=$nfile
	/
	&verano_nml
	lsummer = .false.
	/
	&chem_nml
	mecha='$MECHA'
	model=$AQM_SELECT
	/
End_Of_File
}

limpiar_archivos_viejos() {
    local ayer=$(date -d "-1 days" +%d)
    local ames=$(date -d "-1 days" +%m)
    local ayear=$(date -d "-1 days" +%Y)
    local fayer1="${DOMAINS}/interpolaD01/wrfchemi_d01_${MECHA}_${dominio:0:8}_${ayear}-${ames}-${ayer}_00:00:00"
    local fayer2="${DOMAINS}/interpolaD01/wrfchemi_d01_${MECHA}_${dominio:0:8}_${ayear}-${ames}-${ayer}_12:00:00"
    if [ -f "$fayer1" ] || [ -f "$fayer2" ]; then
        echo "Borrando archivos de ayer: ${ayear}-${ames}-${ayer}"
        rm -f "$fayer1" "$fayer2"
    else
       echo "No se encontraron archivos en ${DOMAINS}/interpolaD01"
    fi
}