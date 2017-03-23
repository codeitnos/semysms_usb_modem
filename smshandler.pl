#!/usr/bin/perl
use strict;
use LWP::Simple;
use JSON;
use Data::Dumper;
use File::Temp;
use File::Copy;
use warnings;
use URI::Escape;
use Device::Gsm;
use Encode qw/encode decode/;


my $url_reg_device = 'https://semysms.net/api/modem/2/post/reg_device.php';
my $url_getsms = 'https://semysms.net/api/modem/2/post/getsms.php';
my $url_setsms = 'https://semysms.net/api/modem/2/post/setsms.php';
my $url_set_sms_status = 'https://semysms.net/api/modem/2/post/set_sms_status.php';

my $smsdevices_conf = '/var/spool/sms/smsdevices.conf';
my $smsdevices_dir = '/var/spool/sms/devices/';
my $code_dir = '/var/spool/sms/code/';
my $smstools_outgoing = '/var/spool/sms/outgoing/';
my $waitforreport_dir = '/var/spool/sms/waitforreport/';
my $tmp_dir = '/tmp';

my $loging=1;# 0,1,2,3,4
my $log_file = '/var/log/smstools/other.log';

my $log;

if ($loging) {open($log, '>>', $log_file) or die};


if (defined $ARGV[1]){
	if ($loging) {print $log "\n".localtime()."\tHandler\t";}
	open(my $file, '<', $ARGV[1]) or die;
	my $is_body=0;
	my $msg = '';
	my $Received;
	my $phone;
	my $Modem;
	my $Flash;
	my $Sent;
	my $Message_id='';
	my $Input_id;
	my $Status;
	my $Discharge_timestamp;
	my $Queue;
	my $Fail_reason;
	my $Failed;
	my $Input_device;
	my $Alphabet;

	while (my $row = <$file>){
		if (($is_body==1)&&( !($ARGV[0] eq 'REPORT') ) ) {$msg.=$row;}
		else {
			my ($x,$y) = split(': ', $row);		
	 		if (defined $y){ 
	 		    chop $y; 
				if ($x eq 'From'){$phone = $y;}
				elsif ($x eq 'Modem'){$Modem = $y;}
				elsif ($x eq 'Flash'){$Flash = $y;}
				elsif ($x eq 'Received'){$Received = '20'.$y;}
				elsif ($x eq 'Sent'){$Sent = '20'.$y;}
				elsif ($x eq 'Message_id'){$Message_id = $y;}
				elsif ($x eq 'Input_id'){$Input_id = $y;}
				elsif ($x eq 'Status'){$Status = $y;}
				elsif ($x eq 'Discharge_timestamp'){$Discharge_timestamp = '20'.$y;}
				elsif ($x eq 'Queue'){$Queue = $y;}
				elsif ($x eq 'Fail_reason'){$Fail_reason = $y;}
				elsif ($x eq 'Failed'){$Failed = '20'.$y;}
				elsif ($x eq 'Input_device'){$Input_device = $y;}
				elsif ($x eq 'Alphabet'){$Alphabet = $y;}			
			}
			else {$is_body=1;}
		}
	}

	my $id= substr($ARGV[1], rindex($ARGV[1], '/')+1);

	if ($ARGV[0] eq 'RECEIVED'){
		$msg= decode($Alphabet, $msg);
		$msg = uri_escape_utf8($msg);	
		open my $file, $smsdevices_conf or die;
		my $device;
		while (my $row = <$file>) {
			my ($modem_name,$path,$imei) = split(' ', $row);	
					
			if ($loging>=4) {print $log '$row: ',$row, "\n";}			
			if (defined $imei){ 
				if ($modem_name eq $Modem){$device = $imei;}
			}
		}	
		if (defined $device){
			my $u = '?device='.$device.'&date='.$Received.'&phone='.$phone.'.&msg='.$msg.'&id='.$id;				
			if ($loging>=2) {print $log "\n",$ARGV[0].' url: ',$u,"\t";}
			my $doc = get $url_setsms.$u;
			if ($loging>=3) {print $log 'ans: ',$doc;}			
		}	
	}

	elsif ($ARGV[0] eq 'SENT'){
		$msg= decode($Alphabet, $msg);
		$msg = uri_escape_utf8($msg);
		my $u = '?device='.$Input_device.'&id='.$Input_id.'&status=1&date_send='.$Sent;
		if ($loging>=2) {print $log "\n",$ARGV[0].' url: ',$u,"\t";}
	  	my $doc = get $url_set_sms_status.$u;
	  	if ($loging>=3) {print $log 'ans: ',$doc;}	  	
	  	open(my $wfr, '>', $waitforreport_dir.$Modem.'-'.$Message_id) or die;
	  	print $wfr $Input_id.' '.$Input_device;
	  	close $wfr;
	}
	elsif ($ARGV[0] eq 'REPORT'){
		if ($loging>=4) {print $log $ARGV[0].' waitforreport_file: ',$waitforreport_dir.$Modem.'-'.$Message_id, "\n";}
	
	  	open(my $wfr, '<', $waitforreport_dir.$Modem.'-'.$Message_id) or die;  	
		my $row = <$wfr>;
		my ($Input_id, $Input_device) = split(' ', $row);   
		close $wfr;
		unlink $waitforreport_dir.$Modem.'-'.$Message_id;
		my $u;
		if (substr($Status,0,5) eq '0,Ok,') 
		  	{$u = '?device='.$Input_device.'&id='.$Input_id.'&status=2&date_deliv='.$Discharge_timestamp.'&date_send='.$Sent;}
		else
			{$u = '?device='.$Input_device.'&id='.$Input_id.'&status=-1&date_deliv='.$Discharge_timestamp.'&date_send='.$Sent;}
		if ($loging>=2) {print $log "\n",$ARGV[0].' url: ',$u,"\t";}
		my $doc = get $url_set_sms_status.$u;
		if ($loging>=3) {print $log 'ans: ',$doc;}
	}
	elsif ($ARGV[0] eq 'FAILED'){
		my $u = '?device='.$Input_device.'&id='.$Input_id.'&status=-2&date_error='.$Failed;
		if ($loging>=2) {print $log "\n",$ARGV[0].' url: ',$u,"\t";}
	  	my $doc = get $url_set_sms_status.$u;
	  	if ($loging>=3) {print $log 'ans: ',$doc;}
	}

}
elsif (defined $ARGV[0]){
	if ($ARGV[0] eq 'scan') {
		my @flist = glob "/dev/ttyUSB*";
		my $i = 0;
		if ($loging) {print $log "\n".localtime()."\tScan\n";}
		open(my $devices_file, '>', $smsdevices_conf) or die;
		`find $smsdevices_dir -type l -delete`;
		`find $code_dir -type f -delete`;
		my %hash = ();
		foreach my $f (@flist){
		 	if (!($f eq '/dev/ttyUSB*')){ 	   
				my $gsm = new Device::Gsm( port => $f);
				if( $gsm->connect( baudrate => 115200) ) {
					my $imei = $gsm->imei();
		 	    	if ( defined $imei){
		 	    		if (!(exists $hash{$imei})){
			 	    		%hash = (%hash, $imei, 0);
			 	    		print "GSM$i $f $imei\n";
				 	    	print $devices_file "GSM$i $f $imei\n";
				 	    	my $dev_link = $smsdevices_dir.'GSM'.$i;									
							`ln -s $f $dev_link`;
							if ($loging>=4) {print " $dev_link \n";}
							$i++;
						}
					}	
				} 
			}	
   		}	
		close $devices_file;
	}
}
else {
	if ($loging) {print $log "\n".localtime()."\tGetTask\t";}
	open my $file, '<', $smsdevices_conf or die;
	while (my $row = <$file>) {
		my ($device_queue, $path, $device) = split(' ', $row);	
	
		my $u = '?device='.$device.'&device_name='.$device_queue.'&dop_name=Modem';
		

		my $doc = get $url_reg_device.$u;
		if ($loging>=2) {print $log "\n",'reg_device url: ',$u,"\t";}
		if ($loging>=3) {print $log 'ans: ',$doc;}
	
	
		my $text = decode_json($doc);
	
		my $code = $text->{'status'}->{'auth_code'};
	
		if ($loging>=4) {print $log "\n",'$code: ',$code;}
		

		if (!($code eq '')){
			open(my $fh, '>', $code_dir.$code) or die;

			close $fh;	
		}
	
	
		$u = '?device='.$device.'&is_send_to_phone=0';
		$doc = get $url_getsms.$u;
		if ($loging>=2) {print $log "\n",'getsms url: ',$u,"\t";}
		if ($loging>=3) {print $log 'ans: ',$doc;}	
		$text = decode_json($doc);
		foreach my $i (@{$text->{'data'}}) {
			my $msg_file = File::Temp::tempnam( $tmp_dir, '' );
			my $msg = $i->{'msg'}; 
			 
			my $sms_text='To: '.($i->{'phone'})."\n";	  
			$sms_text.="UDH: false\n";
			if ($i->{'is_deliv'}==1) 
				{$sms_text.="Report: true\n";}
			else 
				{$sms_text.="Report: false\n";}
		
			$sms_text.='Queue: '.$device_queue."\n";
			$sms_text.='Input_device: '.$device."\n";
			$sms_text.='Input_id: '.($i->{'id'})."\n";
			$sms_text.="Alphabet: UCS2\n";
			if ($msg eq '[PING]') { 
				$sms_text.="Flash: true\n";
				$sms_text.="\n ";
			}
			else{
				$sms_text.="Flash: false\n";
				$sms_text.= "\n".encode("UCS-2BE", $msg);
			}
			if ($loging>=4) {print $log "\n", $sms_text;}
		
			open(my $fh, '>', $msg_file) or die;
			print $fh $sms_text;
			close $fh;
		    	move($msg_file, $smstools_outgoing) or die;
		}
	}
	close $file;
}
if ($loging) {close $log;}
