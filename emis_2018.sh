#!/bin/bash
#
#: Title       : emis_2018.sh
#: Date        : 12/12/2024
#: Author      : "Jose Agustin Garcia Reynoso" <agustin@atmosfera.unam.mx>
#: Version     : 1.0  13/12/2024 Actualizacion para IE del 2018
#: Description : Programa de emisiones con funciones
#: Options     : None
#SBATCH -J emi_2018
#SBATCH -o emi_2018%j.o
#SBATCH -n 1
#SBATCH --cpus-per-task=3
#SBATCH -p id
# Emissions area avalable:
#   bajio bajio3 cdjuarez   colima    ecacor  ecaim ecaim3
#   guadalajara  jalisco    mexicali  mexico  mexico9
#   monterrey    monterrey3 queretaro tijuana centro
#
dominio=centro
# To set spatial distribution = 1 else =0
HacerArea=1
#
# Mechanism selcetion
# avalable:
# cbm04 cbm05 mozart racm2 radm2 saprc99 saprc07 ghg
#
MECHA=radm2
# Si saprc07 AQM_SELECT = 0 WRF 1 CHIMERE
AQM_SELECT=1
#  Build the namelist_emis.nml file
# Cambiar aqui la fecha
mes=10
dia=31
dia2=31
#
#    Aqui cambiar el año a modelar
#
nyear=2018
#
#   Si se desea un archivo de 24 hrs  nfile=1
#              dos archivos de 12 hrs nfile=2
nfile=1

#####  END OF USER MODIFICATIONS  #####
# Normaliza mes y días a dos dígitos (05, 08...). 10# fuerza base decimal para
# que 08 y 09 no se interpreten como octal en las operaciones aritméticas.
mes=$(printf "%02d" $((10#$mes)))
dia=$(printf "%02d" $((10#$dia)))
dia2=$(printf "%02d" $((10#$dia2)))

source functions.sh

check_domain $dominio

make_tmpdir tmp$dominio

hace_namelist $dia $dia

if [ $HacerArea -ne 0 ]; then
    hace_area &
    pid_area=$!
    hace_movil &
    pid_movil=$!
    wait_all "espacial_area:$pid_area" "espacial_movil:$pid_movil"
    echo -e "${COLOR_SUCCESS}Distribución espacial completada.${COLOR_RESET}"
fi

#
# Starts Loop for Time
#
echo -e "     \033[1;44m  Starting run Time Loop   \033[0m"
while [ $((10#$dia)) -le $((10#$dia2)) ] ;do
if [ -d dia$dia ]
then
   cd dia$dia
else
   mkdir dia$dia
   cd dia$dia
fi
fecha_str="${nyear}-${mes}-${dia}"
hace_namelist $dia -$dia
echo "Working Directory "$PWD

crea_anio_csv $nyear $mes $dia

emis_area &
pid_a=$!

emis_fijas &
pid_f=$!

emis_movil &
pid_m=$!

wait_all "emis_area:$pid_a" "emis_fijas:$pid_f" "emis_movil:$pid_m"
    echo "Combinando emisiones y generando archivo final..."
ln -fs ../chem/namelist.* .
run_and_check ../bin/emiss.exe > ../${MECHA}_${dia}.log 2>&1
if [ ! -d ../../inventario/${dominio} ]
  then
    mkdir -p ../../inventario/${dominio}
fi
    mv *00\:00 ../../inventario/${dominio}

cd ..
echo -e "${COLOR_SUCCESS}---> Día $fecha_str procesado exitosamente. $MECHA ${COLOR_RESET}"
 dia=$(printf "%02d" $((10#$dia + 1)))
done
