#!/bin/bash
####################################################################
# The script:
# 1. Extracts SST for a selected timeperiod from a GCM
# 2. Interpolates SST to a finer grid using a combination of bilineal
# 		and distance-weighted average method to fill more gridcells
# 		near the coastlines, to avoid distorsions after metgrid.exe
# 3. Converts the netcdf to grb format, readable in ungrib.exe
#
# Usage:
#
#      ./preprocess_SST.sh <file to preprocess> <start_time> <end_time>
#
# Format of <start_time> and <end_time>:
# 		[year]-[monht]-[day]T[hour]:[minutes]:[seconds]
#  		e.g. 2082-01-01T00:00:00
####################################################################

tos_file=$1            # netcdf with SST file to be preprocessed
tstart=$2              # format e.g. "2082-01-01T00:00:00" 
tend=$3                # format e.g. "2082-02-01T00:00:00" 
sst_gribcode=37        # grib code for SST
sst_mask_gribcode=38    # grib code for SST_mask
sst_mask="False"        # If SST_mask is needed set to True
interval="6hour"        # Interval of needed boundary files

# function to interpolate missing timeintervals
function timeRange2Interval(){
  ifile=$1
  ofile=$2
  ststamp=$3
  etstamp=$4
  nrec=$(cdo -s ntime ${ifile})
  test ${nrec} -eq 0 && nrec=1
  cdo -s seltimestep,1 ${ifile} s1
  cdo -s setdate,$(echo ${ststamp} | awk -FT '{print $1}') s1 s2
  cdo -s settime,$(echo ${ststamp} | awk -FT '{print $2}') s2 s0
  if [ ${nrec} -le 2 ]; then
  	cdo -s seltimestep,${nrec} ${ifile} s1
  	cdo -s setdate,$(echo ${etstamp} | awk -FT '{print $1}') s1 s2
  	cdo -s settime,$(echo ${etstamp} | awk -FT '{print $2}') s2 s1
  	cdo -s mergetime s0 s1 s4
  else
  	cdo -s seltimestep,${nrec} ${ifile} s1
  	cdo -s setdate,$(echo ${etstamp} | awk -FT '{print $1}') s1 s2
  	cdo -s settime,$(echo ${etstamp} | awk -FT '{print $2}') s2 s1
 	ncks -d time,1,$((nrec-1)) ${ifile} s3
  	cdo -s mergetime s0 s3 s1 s4
  	rm s3
  fi
  cdo -s inttime,$(cdo -s showdate s0 | tr -d ' '),00:00:00,${interval} s4  ${ofile}
  rm s0 s1 s2 s4
}

# function for spatial interpolation 
function remap_sst(){
  ifile=$1
  cdo -s remapdis,r720x770 ${ifile} SST_dis.nc
  cdo -s remapbil,r720x770 ${ifile} SST_bil.nc
  cdo -s -O setmisstoc,1000 SST_bil.nc tmp.nc; mv tmp.nc SST_bil.nc
  ncrename -v tos,tos_bil SST_bil.nc
  ncks -A -v tos_bil SST_bil.nc tmp.nc
  ncks -A -v tos SST_dis.nc tmp.nc
  ncap2 -O -s 'where(tos_bil>100) tos_bil=tos;' tmp.nc SST_dis.nc
  ncks -v tos_bil SST_dis.nc SST.nc
  ncrename -v tos_bil,tos SST.nc
  rm tmp.nc SST_dis.nc SST_bil.nc
}

# extract time period
ncks -d time,${tstart},${tend} ${tos_file} tmp00.nc
ncks -d time,${tend} ${tos_file} tmp01.nc
ncrcat tmp00.nc tmp01.nc tmp0.nc
rm tmp00.nc tmp01.nc 

# interpolate of SST with gap filling near the coast
remap_sst tmp0.nc
rm tmp0.nc

# convert units to K
cdo -s addc,273.15 SST.nc SST2K.nc; mv SST2K.nc SST.nc

#Interpolate monthly to 6 hoursly for 1 month (from 1.1.2081 to 1.2.2081
timeRange2Interval SST.nc tmp.nc ${tstart} ${tend} ; mv tmp.nc SST.nc

# create grib file for SST
cdo -s -a -f grb copy SST.nc SST.grb
cdo -s chparam,1,${sst_gribcode} SST.grb tmp.grb
cdo -s setltype,1 tmp.grb SST.grb; rm tmp.grb

if [ ${sst_mask} == "True" ]; then 
  # create land-sea mask
  cdo -s setrtoc,-999,999,1 SST.nc tmp.nc
  cdo -s setmisstoc,0 tmp.nc SST_mask.nc
  rm tmp.nc
  
  # create grib file for SST_mask
  cdo -s -a -f grb copy SST_mask.nc SST_mask.grb
  cdo -s chparam,1,${sst_mask_gribcode} SST_mask.grb tmp.grb
  cdo -s setltype,1 tmp.grb SST_mask.grb; rm tmp.grb
fi

