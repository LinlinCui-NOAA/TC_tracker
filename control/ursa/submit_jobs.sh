#!/bin/bash

set -x

# scipt to submit hurricane track jobs
submit_with_check() {
    local jobid
    jobid=$(eval "$@")
    if [[ $? -ne 0 || -z "$jobid" ]]; then
        echo "Failed to submit job: $*" >&2
        exit 1
    fi
    echo "$jobid"
}

source ./atparse.bash
source ./submitjobwait.bash

# experiment configurations:
export PDY=${1:-20250709}
export CYC=${2:-00}
#member: EAGLE_SOLO:"", EAGLE_ENSEMBLE:c00, p01, ... , p30, weight: 0, 1, 2, ..., 30
export PERT=${3:-"p01"}
#run directories
export PACKAGEROOT=${4:-/scratch3/NCEPDEV/nems/Jun.Wang/tracker/20250612/test/TC_tracker}
export DATAROOT=${5:-/scratch3/NCEPDEV/stmp/Jun.Wang/ptmp}
export COMINSYN=${6:-/scratch3/NCEPDEV/nems/Jun.Wang/tracker/input/syndat}

export COMROOT=${DATAROOT}/com
if [ "$PERT" = "" ]; then
   export COMINGFS=/scratch3/NCEPDEV/nems/Jun.Wang/tracker/input/graphcastgfs.${PDY}
   export ENSMEMBER=""
   export MODELNAME="ggfs"
#model version: "", or "_test"
   export modelversion=""
   export outputs3dir=graphcastgfs.${PDY}/${CYC}/forecasts_13_levels${modelversion}
   export JBNME=jAIGFS_cyclone_track${modelversion}
else
   export COMINGFS=/scratch3/NCEPDEV/nems/Jun.Wang/tracker/input/pmlgefs.${PDY}
   pertmember=`echo $PERT | cut -c2-3`
   weight=$(expr $pertmember + 0)
   export ENSMEMBER=forecasts_13_levels_${PERT}_model_${weight}
   export MODELNAME="g"${PERT}
   export outputs3dir=EAGLE_ensemble/pmlgefs.${PDY}/${CYC}/${ENSMEMBER}
   export JBNME=jAIGFS_cyclone_track_${PERT}
fi
# sync data
export clustername=ursa
export SCHEDULER="slurm"
module use ../../modulefiles
module load ursa.lua
module load stack-oneapi
module load awscli-v2/2.15.53
module list

#model history files
aws s3 --profile gcgfs sync s3://noaa-nws-graphcastgfs-pds/hurricanes/syndat $COMINSYN

atparse < ./jAIGFS_cyclone_track_00.ecf_tmpl > job_card
submit_and_wait job_card

# send data to S3 bucket
outputfile=${MODELNAME}p.t${CYC}z.cyclone.trackatcfunix
outputldir=${COMROOT}/aigfs.${PDY}/${CYC}/products/atmos/cyclone/tracks
if [ -s "${outputldir}/$outputfile" ]; then
   aws s3 --profile gcgfs cp ${outputldir}/$outputfile s3://noaa-nws-graphcastgfs-pds/${outputs3dir}/$outputfile
   echo "Track file is sent on $PDY at $CYC cycle"
else
   echo "NO track file on $PDY at $CYC cycle"
fi


