#!/bin/bash
ldconfig

if [ $PMI_RANK -eq 0 ] ; then
  echo "ray start head"
  ray start --head --node-ip-address="$head_node_ip" --port=$port --num-cpus 32 --num-gpus 4 --temp-dir=/tmp --block &
  while ! ray status --address="$ip_head" &>/dev/null ; do
    sleep 5
  done
  echo "starting prediction"
  python /app/AlphaPulldown/alphapulldown/scripts/run_multimer_jobs.py "$@"
  echo "control outside python"
  #qdel $PBS_JOBID
else
  worker_ip=$(hostname -i)
  echo "worker IP" $worker_ip
  # if we detect a space character in the head node IP, we'll
  # convert it to an ipv4 address. This step is optional.
  if [[ "$worker_ip" == *" "* ]]; then
  IFS=' ' read -ra ADDR <<<"$worker_ip"
  if [[ ${#ADDR[0]} -gt 16 ]]; then
    worker_ip=${ADDR[1]}
  else
    worker_ip=${ADDR[0]}
  fi
  echo "IPV6 address detected. We split the IPV4 address as $worker_ip"
  fi

  while ! ray status --address="$ip_head" &>/dev/null ; do
    sleep 5
  done
  echo "ray start worker"
  ray start --address "$ip_head" --node-ip-address=$worker_ip  --num-cpus 32 --num-gpus 4  --temp-dir=/tmp --block &
  wait
fi
