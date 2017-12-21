#!/bin/bash


usage() {
    echo "Usage:"
    echo "$basename $0 <config_file>"
    echo 
}


if [[ "$1" == "-h" || "$1" == "--help" || "$#" < 1 ]]; then
    usage
    exit
fi
exec {FD}<$1
echo "opened $1 for reading using descriptor ${FD}"


# ---------------------------------------------
#                 Functions
# ---------------------------------------------



readInterfaces() {
    echo "Setup Addresses ..."
    while read -u $1 -r intf addresses # ipv4 ipv6
    do
        [[ "${intf:0:1}" ==  "#" ]] && continue

        if [[ -z "$intf" ]]; then 
            return 
        fi

        if [[ "$intf" == "eth0" ]]; then 
            echo "WARNING: not touching eth0"
            continue
        fi

        echo
        echo "configure $intf"


        if [[ -z "$addresses" ]]; then 
            echo "  Turn off interface: $intf"
            sudo ip link set down $intf
            continue
        fi

        sudo ip link set up $intf

        echo "  Turn off ipv6 Router advertisements ..."
        sudo sysctl -w net.ipv6.conf.$intf.accept_ra=0 > /dev/null
        sudo sysctl -w net.ipv6.conf.$intf.autoconf=0  > /dev/null


        # delete ipv6 addresses
        for a in $(ip -6 a s $intf| awk '/inet6.*scope global/ {print $2}'); do
            echo "  Delete $a"
            sudo ip -6 a del $a dev eth3 
        done

        # delete ipv4 addresses
        for a in $(ip a s $intf | awk '/inet .*scope global/ {print $2}'); do
            echo "  Delete $a"
            sudo ip a del $a dev $intf 
        done

        for  adr in $addresses
        do
            if [[ $adr =~ ^[0-9A-Fa-f:]+$ ]]; then
                echo "  Add ipv6 $adr"
                sudo ip -6 a a $adr dev $intf
            else 
                echo "  Add ipv4 $adr"
                sudo ip a a $adr dev $intf
            fi
        done


    done 
}


readRoutes() {
    echo "Setup Routes ..."
    while read -u $1 -r dest intf gateway
    do
        [[ "${dest:0:1}" ==  "#" ]] && continue

        if [[ "$intf" == "eth0" ]]; then 
            echo "WARNING: not touching eth0"
            continue
        fi
        
        if [[ -n "$gateway" ]]; then
            sudo ip r a $dest via $gateway dev $intf
        else
            sudo ip r a $dest dev $intf
        fi
    done 
}






# ---------------------------------------------
#                     MAIN
# ---------------------------------------------


while read -u ${FD} -r line
do
    [[ "${line:0:1}" ==  "#"            ]] && continue
    [[ "${line}"     ==  "[interfaces]" ]] && readInterfaces ${FD}
    [[ "${line}"     ==  "[routes]"     ]] && readRoutes ${FD}
done 
echo "Done"


