sudo apt-get install libjson-perl
sudo apt-get install smstools
sudo apt-get install libwww-perl
sudo apt-get install libdevice-gsm-perl

#sudo chmod a+rw /dev/ttyUSB*
#sudo apt-get install usb-modeswitch

sudo chmod a+rw /var/spool/sms -R

mkdir /var/spool/sms/GSM0
mkdir /var/spool/sms/GSM1
mkdir /var/spool/sms/GSM2
mkdir /var/spool/sms/GSM3
mkdir /var/spool/sms/GSM4
mkdir /var/spool/sms/GSM5
mkdir /var/spool/sms/waitforreport
mkdir /var/spool/sms/code
mkdir /var/spool/sms/devices

sudo chmod a+rw /var/spool/sms -R
sudo touch /var/log/smstools/other.log
sudo chmod a+rw /var/log/smstools/other.log
sudo touch /var/log/modem.log
sudo chmod a+w /var/log/modem.log





