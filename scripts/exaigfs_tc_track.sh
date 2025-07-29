#!/bin/ksh 
set -x

export cmodel=${cmodel:-gfs}
export loopnum=1
export ymdh=${PDY}${cyc}

export gfsdir=${COMINgfs}/${cyc}/${ensmember}

export pert=${pert:-"p01"}
pertdir=${DATA}/${cmodel}/${pert}
mkdir -p $pertdir

#-----------input data checking -----------------
#${USHens_tracker}/data_check.sh 
#${USHens_tracker}/data_check_gfs.sh
## exit code 6 = missing data of opportunity
#if [ $? -eq 6 ]; then exit; fi
#------------------------------------------------

outfile=${pertdir}/trkr.${cmodel}.${pert}.${ymdh}.out

if [[ -d /scratch3 ]] ; then
  # We are on NOAA Ursa
  echo "on Ursa, call extrkr_aigfs.sh"
  machine=ursa
  ${USHens_tracker}/extrkr_aigfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /work ]] ; then
  # We are on MSU Orion 
  machine=orion
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs4/HFIP ]] ; then
  # We are on NOAA Jet
  machine=jet
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

elif [[ -d /lfs/h1 ]] ; then
  # We are on NOAA WCOSS2
  machine=wcoss2
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}  

elif [[ -d /gpfs/f6 ]] ; then
  # We are on NOAA gaeac6
  machine=gaeac6
  ${USHens_tracker}/extrkr_gfs.sh ${loopnum} ${cmodel} ${ymdh} ${pert} ${pertdir} #2>&1 >${outfile}

else
  export machine=unknown
  echo Job failed: unknown platform 1>&2
  err_exit "FAILED ${jobid} - ERROR IN unknown platform - ABNORMAL EXIT"

fi
export err=$?; err_chk

if [ "$SENDCOM" = 'YES' ]; then
  if [ "$cmodel" = "gfs" ]; then
     filename = $(echo "$modelname" | tr '[:upper:]' '[:lower:]')
     cat ${pertdir}/trak.avno.atcfunix.${PDY}${cyc} | \
        sed s:AVNO:${modelname}:g \
       > ${COMOUT}/${filelname}.t${cyc}z.cyclone.trackatcfunix
     cat ${pertdir}/long.avno.atcfunix.${PDY}${cyc} | \
        sed s:AVNO:${modelname}:g \
       > ${COMOUT}/${filelname}p.t${cyc}z.cyclone.trackatcfunix
   fi
fi

#############################################################

