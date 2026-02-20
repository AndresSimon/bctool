#!/bin/bash
#SBATCH --job-name=bctool
#SBATCH --output=bctool%j.out
#SBATCH --error=bctool%j.error
#SBATCH --ntasks=1
###SBATCH --qos=long
#SBATCH --ntasks-per-node=1
#SBATCH --cpus-per-task=1
#SBATCH --time=24:00:00
#SBATCH --mem=20G
#SBATCH --hint=nomultithread
#SBATCH --mail-user=simon@ifca.unican.es
#SBATCH --partition=meteo_long
##SBATCH --partition=wncompute_meteo
##SBATCH --exclude=wncompute051
##SBATCH --exclusive
##SBATCH --mem-per-cpu=3G
##SBATCH --exclude=wncompute070
##SBATCH --nodelist=wncompute055

##source /oceano/gmeteo/users/asimon/automamba/bin/activate /oceano/gmeteo/users/asimon/automamba/envs/pyclimenv
export PATH=/oceano/gmeteo/users/asimon/automamba/bin:$PATH
source /oceano/gmeteo/users/asimon/automamba/bin/activate pyclimenv
##conda activate pyclimenv
#./preprocessor.ESGF "1948-09-01_00:00:00" "1949-02-22_23:00:00" BCtables/BCtable.MPIESM12HR
./preprocessor.ESGF "2015-12-01_00:00:00" "2015-12-5_23:00:00" BCtables/BCtable.EC-Earth3-Veg_ssp370
