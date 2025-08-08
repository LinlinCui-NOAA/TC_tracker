#!/bin/bash
set -eu

submit_and_wait() {
  echo "Submitting job on scheduler: ${SCHEDULER}"
  [[ -z $1 ]] && exit 1

  local -r job_card=$1

  case ${SCHEDULER} in
    pbs)
      qsubout=$( qsub "${job_card}" )
      re='^([0-9]+)(\.[a-zA-Z0-9\.-]+)$'
      [[ "${qsubout}" =~ ${re} ]] && jobid=${BASH_REMATCH[1]}
      ;;
    slurm)
      slurmout=$( sbatch "${job_card}" )
      re='Submitted batch job ([0-9]+)'
      [[ "${slurmout}" =~ ${re} ]] && jobid=${BASH_REMATCH[1]}
      ;;
    *)
      echo "Unsupported scheduler: ${SCHEDULER}"
      exit 1
      ;;
  esac

  echo "Submitted Job. ID is ${jobid}."
  sleep 10
  # wait for the job to enter the queue
  local count=0
  local job_running=''
  echo "rt_utils.sh: Job is waiting to enter the queue..."
  until [[ ${job_running} == 'true' ]]
  do
    case ${SCHEDULER} in
      pbs)
        set +e
        job_info=$( qstat "${jobid}" )
        set -e
        ;;
      slurm)
        job_info=$( squeue -u "${USER}" -j "${jobid}" )
        ;;
      *)
        ;;
    esac
    if grep -q "${jobid}" <<< "${job_info}"; then
      job_running=true
      continue
    else
      job_running=false
    fi

    sleep 5
    (( count=count+1 ))
    if [[ ${count} -eq 13 ]]; then echo "No job in queue after one minute, exiting..."; exit 2; fi
  done
  echo "Job (${jobid}) is now in the queue."

  # wait for the job to finish and compare results
  local n=1
  until [[ ${job_running} == 'false' ]]
  do
    case ${SCHEDULER} in
      pbs)
        set +e
        job_info=$( qstat "${jobid}" )
        set -e
        if grep -q "${jobid}" <<< "${job_info}"; then
          job_running=true
          # Getting the status letter from scheduler info
          status=$( grep "${jobid}" <<< "${job_info}" )
          status=$( awk '{print $5}' <<< "${status}" )
        else
          job_running=false
          status='COMPLETED'
          set +e
          exit_status=$( qstat "${jobid}" -x -f | grep Exit_status | awk '{print $3}')
          set -e
          if [[ ${exit_status} != 0 ]]; then
            status='FAILED'
          fi
        fi
        ;;
      slurm)
        job_info=$( squeue -u "${USER}" -j "${jobid}" -o '%i %T' )
        if grep -q "${jobid}" <<< "${job_info}"; then
          job_running=true
        else
          job_running=false
          job_info=$( sacct -n -j "${jobid}" --format=JobID,state%20,Jobname%128 | grep "^${jobid}" | grep "${JBNME}" )
        fi
        # Getting the status letter from scheduler info
        status=$( grep "${jobid}" <<< "${job_info}" )
        status=$( awk '{print $2}' <<< "${status}" )
        ;;
      *)
        ;;
    esac

    case ${status} in
      #waiting cases
      #pbs: Q
      #Slurm: (old: PD, new: PENDING)
      Q|PD|PENDING)
        status_label='Job waiting to start'
        ;;
      #running cases
      #pbs: R
      #slurm: (old: R, new: RUNNING)
      R|RUNNING|COMPLETING)
        status_label='Job running'
        ;;
      #held cases
      #pbs only: H
      H)
        status_label='Job being held'
        echo "*** WARNING ***: Job in a HELD state. Might want to stop manually."
        ;;
      #fail/completed cases
      #slurm: F/FAILED TO/TIMEOUT CA/CANCELLED
            F|TO|CA|FAILED|TIMEOUT|CANCELLED)
        echo "!!!!!!!!!!JOB TERMINATED!!!!!!!!!! status=${status}"
        job_running=false #Trip the loop to end with these status flags
        interrupt_job
        exit 1
        ;;
      #completed
      #pbs: C-Complete E-Exiting
      #slurm: CD/COMPLETED
      C|E|CD|COMPLETED)
        status_label='Completed'
        ;;
      *)
        status_label="Unknown"
        echo "*** WARNING ***: Job status unsupported: ${status}"
        echo "*** WARNING ***: Status might be non-terminating, please manually stop if needed"
        ;;
    esac

    echo "${n} min. ${SCHEDULER^} Job ${jobid} Status: ${status_label} (${status})"

    (( n=n+1 ))
    sleep 60 & wait $!
  done
}

