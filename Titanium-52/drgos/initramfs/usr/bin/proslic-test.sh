#!/bin/ash
trap 'signal_handler' 1 2 3 15

signal_handler() {
  logger -s "signal caught, exit..."
  exit 0
}

i=1
version=`uname -r`

while [ $i -le 100 ]
do
  rmmod proslic.ko
  insmod /lib/modules/$version/proslic.ko tdm_coding=2 flash_time=500 spi_cs=0
  echo 'i = ' $i

  i=`expr $i + 1`
done


