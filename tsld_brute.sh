#!/usr/bin/bash


list="TLD.txt"
process=50
timeout=2
httpport=80
udpport=53

usage(){
  echo -e """top and second level brute forcer
usage:

-s, --sld                      Test top AND second level domain
-c, --custom  [LIST]           Test a custom list (1 t/sld per line with dot)
-T, --tcp                    * TCP ping
-x, --http-port                TCP port 
-u, --udp                    * UDP ping
-X, --udp-port                 UDP port 
-i, --icmp                     ICMP ping (by default if bi ither protocol is specified)
-j, --jobs    [NUMBER]         Number of jobs
-t, --target  [BASEDOMAIN]     Base domain (ex: google)
-T, --timeout [NUMBER]         Timeout for ping
-o, --output  [FILE]           Output file
-v, --verify                   Fast verify with whois but some false positive
-V, --accurate-verify          Accurate verify with whois (slow)

args with * must be run as root.

exemples:

bash tsld_brute.sh -t sparrowslockpicks -V -i -T -o out.txt -j 100
./tsld_brute.sh -t sparrowslockpicks

"""
  exit 1
}
if [[ ${#@} > 0 ]]; then
  while [ "$1" != "" ]; do
    case $1 in
      -s | --sld )
        list="TSLD.txt"
        ;;
      -c | --custom-list)
        shift
        list="$1"
        ;;
      -T | --tcp )
        tcp=true
        ;;
      -u | --udp )
        udp=true
        ;;
      -i | --icmp)
        icmp=true
        ;;
      -x | --http-port )
        shift
        [[ $1 -eq $1 ]] && httpport=$1 || usage
        ;;
      -X | --udp-port )
        shift
        [[ $1 -eq $1 ]] && udpport=$1 || usage
        ;;
      -j | --jobs )
        shift
        [[ $1 -eq $1 ]] && process=$1 || usage
        ;;
      -t | --target )
        shift
        target="$1"
        ;;
      -T | --timeout ) 
        shift
        timeout="$1"
        ;;
      -v | --verify)
        verify=true
        ;;
      -V | --accurate-verify)
        verify=true
        accurate=true
        tmpfile=$(mktemp /tmp/abc-script.XXXXXX)
        exec 3<>"$tmpfile"
        rm "$tmpfile"
        ;;
      -o | --output )
        shift
        output=true
        [[ "${1:0:1}" == '-' ]] && usage    
        outfile="$1"
        ;;
      * )
        usage
        ;;
    esac
    shift
  done
else
  usage
fi


[ -z "$target" ] && usage
if [[ -z $tcp ]] && [[ -z $udp ]]; then
  icmp=true
else
  if [[ $UID != 0 ]]; then
    echo "NEED ROOT FOR TCP OR UDP PING ..." 
    exit 1
  fi
fi

verify() {
  target="$1"
  proto="$2"
  timeout -s1 --preserve-status $3 whois "$1" 2>/dev/null | grep -qE 'does not exist|^No match|^NOT FOUND|^Not fo|AVAILABLE|^No Data Fou|has not been regi|No entria|^The queried object does not exi|cancelled, suspended, refused or reser|available for registra|^Domain Status: free|NO OBJECT FOUND!|^This TLD has no whois serv|You exceeded the max|Please try aga|Invalid query|DOMAIN NOT FOUND|^No entri|^Domain not found.' >/dev/null 2>&1
  [[ $? == 1 ]] || return 1 && echo -ne "\r\033[0K\e[32m[$target]-→[$proto]--→[WHOIS]\e[0m\n" && echo "$domain" "$proto"  >&3 && return 0
}


ping_target(){
  domain="$target$1"
  if [[ $icmp == true ]]; then
    echo -ne "\r\e[0K[$domain]--→[ICMP]"
    ping -c 1 -w $timeout "$domain" > /dev/null 2>&1
    if [[ $? == 0 ]]; then
      if [[ $verify = true ]]; then
        verify "$domain" "ICMP" 3 
        [[ $? == 0 && $output == true && $accurate != true ]] && echo "$domain" >> $outfile
        return 0
      else 
        echo -ne "\r\e[0K\e[32m[$domain]--→[ICMP]\e[0m\n" && return 0
      fi
    fi
  fi
  if [[ $tcp == true ]]; then
    echo -ne "\r\e[0K[$domain]--→[TCP]"
    timeout $timeout nping -c1  --tcp -p $httpport "$domain" 2>/dev/null | grep "Rcvd: 1" > /dev/null 2>&1 
    if [[ $? == 0 ]]; then
      if [[ $verify = true ]]; then
        verify "$domain" "TCP" 3
        [[ $? == 0 && $output == true && $accurate != true ]] && echo "$domain" >> $outfile
        return 0
      else
        echo -ne "\r\e[0K\e[32m[$domain]--→[TCP]\e[0m\n" && return 0
      fi
    fi
  fi
  if [[ $UDP == true ]]; then
    echo -ne "\r\e[0K[$domain]--→[UDP]"
    nping -c1  --udp -p $udpport "$domain" | grep "Rcvd: 1" 2>&1 >/dev/null
    if [[ $? == 0 ]]; then
      if [[ $verify = true ]]; then
        verify "$domain" "UDP" 3
        [[ $? == 0 && $output == true && $accurate != true ]] && echo "$domain" >> $outfile
        return 0
      else
        echo -ne "\r\033[0K\e[32m[$domain]--→[UDP]\e[0m\n" && return 0
      fi
    fi
  fi
}


pwait(){
  while [ $(jobs -p | wc -l) -ge $1 ]; do
    sleep 1
  done
}

while IFS= read line; do
  ping_target "$line" &
  pwait $process
done < "$list"
wait
echo -ne "\r\033[0K\n"

echo -e "\e[0mVERIFIED:"
while IFS= read -r line; do
  verify "$(cut -d " " -f1 <<<$line)" "$(cut -d " " -f2 <<<"$line")" 5
  [[ $? == 0 && $output == true ]] && echo "$(cut -d " " -f1 <<<$line)" >> $outfile
  sleep 1 
done < <({ exec < /dev/stdin; cat; } <&3)
