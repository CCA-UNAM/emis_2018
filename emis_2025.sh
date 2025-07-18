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
#SBATCH -n 4
#SBATCH --ntasks-per-node=24
#SBATCH -p id
# Emissions area avalable:
#   bajio bajio3 cdjuarez   colima    ecacor  ecaim ecaim3
#   guadalajara  jalisco    mexicali  mexico  mexico9
#   monterrey    monterrey3 queretaro tijuana
#
dominio=ecacor
# To set spatial distribution = 1 else =0
HacerArea=0
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
mes=04
dia=29
dia2=30
#
#    Aqui cambiar el año a modelar
#
nyear=2025
#
#   Si se desea un archivo de 24 hrs  nfile=1
#              dos archivos de 12 hrs nfile=2
nfile=1

#####  END OF USER MODIFICATIONS  #####
source functions.sh

check_domain $dominio

make_tmpdir tmp$dominio

hace_namelist $dia $dia

hace_area &

hace_movil

wait

#
# Starts Loop for Time
#
echo -e "     \033[1;44m  Starting run Time Loop   \033[0m"
while [ $dia -le $dia2 ] ;do
if [ -d dia$dia ]
then
   cd dia$dia
else
   mkdir dia$dia
   cd dia$dia
fi
hace_namelist $dia -$dia
echo "Working Directory "$PWD

crea_anio_csv $nyear $mes $dia

emis_area &

emis_fijas &

emis_movil &

wait

ln -fs ../chem/namelist.* .
../bin/emiss.exe  > ../${MECHA}.log
if [ ! -d ../../inventario/${dominio} ]
  then
    mkdir -p ../../inventario/${dominio}
fi
    mv *00\:00 ../../inventario/${dominio}

cd ..
echo -e "     \033[1;44m  DONE STORING "$MECHA $dia "\033[0m"
 let dia=dia+1
done
