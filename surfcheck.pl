#!/usr/bin/perl5
#
# Gathers information for an HTML surf report.

##############################
# Configuration
#

$http_get = "/web/oregonsurfcheck.com/bin/http_get";
$xtide = "/web/oregonsurfcheck.com/bin/tide";
$convert = "/usr/local/bin/convert";
#$DEBUG = 1;

##############################
# Data Source URLs
#

$NWS_Coastal_Primary_URL = 
   "http://www.wrh.noaa.gov/pqr";
   "http://www.wrh.noaa.gov/total_forecast/marine.php?marine=PZZ255";
$NWS_Coastal_Data_URL =
 # "http://www.ocs.orst.edu/pub_ftp/weather/marine_forecast/marine.PQR.txt";
   "http://www.wrh.noaa.gov/total_forecast/marine.php?marine=PZZ255";

$WAM_Index_URL =
#   "https://www.fnmoc.navy.mil/wxmap_cgi/cgi-bin/wxmap_all.cgi?type=prod&area=27km_epac&prod=swlwvht&dtg=2010011012&set=SeaState";
    "https://www.fnmoc.navy.mil/wxmap_cgi/cgi-bin/wxmap_single.cgi?area=27km_epac&dtg=2010011512&prod=swlwvht&tau=000&set=All";
$WAM_Current_URL =
#  "https://www.fnmoc.navy.mil/ww3_cgi/dynamic/ww3.w.npac.swl_wav_ht.000.gif";
   "https://www.fnmoc.navy.mil/wxmap_cgi/dynamic/27KM_COAMPS_E_PAC/2010011000/27km_coamps_e_pac10.swlwvht.012.e_pac.gif";
$WAM_24hr_URL =
#  "https://www.fnmoc.navy.mil/ww3_cgi/dynamic/ww3.w.npac.swl_wav_ht.024.gif";
   "https://www.fnmoc.navy.mil/wxmap_cgi/dynamic/27KM_COAMPS_E_PAC/2010011000/27km_coamps_e_pac10.swlwvht.036.e_pac.gif";

$Tide_URL = 
  "http://tbone.biol.sc.edu/tide/sitesel.html";

@Buoys_List = ( 46005, 46002, 46050, 46029, 46089, 46015 );
%Buoys_Names = 
  ( 46005, "Offshore N", 46002, "Offshore S", 46050, "Newport", 46029, "Columbia Bar" , 46089, "Tillamook", 46015, "Port Orford" );
$Buoys_Data_URL = 
  "http://www.ndbc.noaa.gov/data/realtime2/";
$Buoys_Index_URL = 
  "http://seaboard.ndbc.noaa.gov/maps/WestCoast_inset.shtml";

@Wind_Buoys_List = ( ASTO3, TLBO3, SBEO3, NWPO3, CARO3, PORO3 );
%Wind_Buoys_Names = 
  ( ASTO3, "Astoria", TLBO3, "Garibaldi", NWPO3, "Newport", SBEO3, "South Beach" , CARO3, "Cape Arago", PORO3, "Port Orford" );
$Wind_Buoys_Data_URL = 
  "http://www.ndbc.noaa.gov/data/realtime2/";

$HMSC_Data_URL =
  "http://cil-www.oce.orst.edu:8080/wavereport";
$HMSC_Index_URL = 
  "http://cil-www.oce.orst.edu:8080/agate.html";


##############################
# Headers
#

require "ctime.pl";
require "Time/gmtime.pm";
require "timelocal.pl";
use LWP qw(/web/oregonsurfcheck.com/lib/perl);
use Crypt::SSLeay qw(/web/oregonsurfcheck.com/lib/perl);


##############################
# HTTP/HTTPS Utilities
#

# https_save(url, filename)
sub https_save {
    local($url) = $_[0];
    local($file_out) = $_[1];

    my $ua = LWP::UserAgent->new(); 
    my $response = $ua->get($url);
     
    if ($DEBUG) { print "https_save($url $filename)\n"; }

    if ($response->is_success) {
	if (!open (HTTPS_OUTFILE, ">$file_out")) {
            if ($DEBUG) {
	        print "Failed to write output file $file_out for https content\n";
            }
	    return 0;
	}
	print (HTTPS_OUTFILE $response->content);
	close HTTPS_OUTFILE;
	return 1;
    } else {
        if ($DEBUG) {
            printf("Failed to retrieve $url - %s\n", $response->status_line);
        }
	return 0;
    }
}


##############################
# Time Management
#

# Timezone offset between the server (eastern US) and data points (Pacific US)
$ServerOffset = 10800;

# Timezone offset between the server local and GMT
@gmt = gmtime($^T);
@lct = localtime($^T);
$GMTOffset = timegm(@gmt) - timegm(@lct);

sub month2num_short {
    local($mon) = $_[0];
    local(%monthnum) = (
			'jan', 0,
			'feb', 1,
			'mar', 2,
			'apr', 3,
			'may', 4,
			'jun', 5,
			'jul', 6,
			'aug', 7,
			'sep', 8,
			'oct', 9,
			'nov', 10,
			'dec', 11,
			);
    $mon =~ y/A-Z/a-z/;
    $monthnum{$mon};
}


# returns 1 if the data is good, 0 if out of date
# Usage: &check_time(<data_time>, <timeout>)
#   data_time: data update time GMT
#   timeout: reject after timeout hours
sub check_time {
    local($data_time) = $_[0];
    local($timeout) = $_[1] * 3600;  # 1 hour

    # Reject if the data is more than $timeout out of date
    if($^T - $data_time > $timeout) {
	return(0);
    } else {
	return(1);
    }
}


##############################
# Data Unit Conversion Utilities
#

sub convertDir {
  local($dir) = $_[0];

  if(($dir > 338 && $dir <= 360) || ($dir >= 0 && $dir <= 22)) { return("N"); }
  if($dir > 22  && $dir <= 67 ) { return("NE"); }
  if($dir > 67  && $dir <= 112) { return("E"); }
  if($dir > 112 && $dir <= 157) { return("SE"); }
  if($dir > 157 && $dir <= 202) { return("S"); }
  if($dir > 202 && $dir <= 247) { return("SW"); }
  if($dir > 247 && $dir <= 292) { return("W"); }
  if($dir > 292 && $dir <= 338) { return("NW"); }
  return("--");
}  

sub meters2feet {
  local($m) = $_[0];

  return($m / .3048);
}

sub mps2knots {
  local($m) = $_[0];

  return($m * 1.9438445);
}


##############################
# Data Collection
#

# Arg 1 is the file handler to output to
sub getHMSC {
  local($OUTFILE) = $_[0];
  local($in) = "";
  local($out) = "";

  if ($DEBUG) { print "Getting HMSC\n"; }

  if (!https_save($HMSC_Data_URL, "/tmp/wavereport")) {
     system "rm -f /tmp/wavereport";
     if ($DEBUG) {
         print($OUTFILE "<I>Couldn't retrieve HMSC Data<\/I>\n");
     }
     return;
  }

  open(WRFILE,"/tmp/wavereport") || return;
  while (<WRFILE>) {
    chop($_);
    $out = join(" ", $out, $_);
  }
  close(WRFILE);

  $i = index($out, "Prepared at");
  if ($i < 0) {
      system "rm -f /tmp/wavereport";
      if ($DEBUG) {
          print($OUTFILE "<I>Couldn't retrieve HMSC Data<\/I>\n");
      }
      return;
  }
  $data_time = &timegm( int(substr($out, $i+29, 2)),
			int(substr($out, $i+26, 2)),
			int(substr($out, $i+23, 2)),
			int(substr($out, $i+20, 2)),
			&month2num_short(substr($out, $i+16, 3)),
			int(substr($out, $i+36, 4))-1900,
			0, 0, 0 ) + $ServerOffset + $GMTOffset;

  if(!(&check_time($data_time, 24))) {
      $hgt = "--";
      $per = "--";
  } 
  else {
      $i = index($out, "height:");
      $j = index($out, "period:");
      $hgt = sprintf("%.1f", &meters2feet(substr($out, $i+7, 6)));
      $per = sprintf("%.1f", substr($out, $j+7, 7));
  }

  print($OUTFILE "<TABLE BORDER>\n");
  print($OUTFILE "<TR ALIGN=LEFT><TD><\/TD><TD><B><FONT SIZE=-1>Height<\/FONT><\/B><\/TD><TD><B><FONT SIZE=-1>Period<\/FONT><\/B><\/TD><\/TR>\n");

  $out = sprintf("<TR ALIGN=LEFT><TD><B><FONT SIZE=-1>Newport<\/FONT><\/B><\/TD><TD><FONT SIZE=-1>%s ft<\/FONT><\/TD><TD><FONT SIZE=-1>%s s<\/FONT><\/TD><\/TR>\n", $hgt, $per);
  print($OUTFILE $out);
  print($OUTFILE "<\/TABLE>\n");

  system "rm -f /tmp/wavereport";
}  


# Arg 1 is the file handler to output to
sub getNWSInfo {
  local($OUTFILE) = $_[0];
  local($in) = "";
  local($out) = "";
  local($i,$j,$k) = (0,0,0);

  # Get the NWS file 

  if ($DEBUG) { print "Getting NWS Info\n"; }

  if (!https_save($NWS_Coastal_Data_URL, "/tmp/marine.PDX")) {
      system "rm -f /tmp/marine.PDX";
      if ($DEBUG) {
          print($OUTFILE "<I>Couldn't retrieve NWS Forcast<\/I><BR>\n");
      }
      return;
  } 

  open(NWSFILE,"/tmp/marine.PDX") || return;
  while (<NWSFILE>) {
    chop($_);
    $out = join(" ", $out, $_);
  }

  # Extract the Florence section 
  #  XXX Changed the zone headers to be less specific.  The actual zones
  #  used in reports seem to vary and sometimes the search fails full zones.
  $i = index($out, "PZZ255");

  if($i == $[-1) {
    seek(NWSFILE, 0, 0);
    $i = index($out, "PZZ250");
  }
  if($i == $[-1) {
    seek(NWSFILE, 0, 0);
    $i = index($out, "PZZ275");
  }
  if($i == $[-1) {
    seek(NWSFILE, 0, 0);
    $i = index($out, "PZZ270");
  }
  if($i == $[-1) {
    if ($DEBUG) {
      print "Zone parsing FAILED\n";
    }
    $out = "<I>Couldn't retrieve NWS Forcast<\/I>";
    print($OUTFILE "$out\n");
    close(NWSFILE);
    system "rm -f /tmp/marine.PDX";
    return;
  }

  if ($DEBUG) {
    print "Start: $i\n";
  }

  $j = index($out, "<\/font>", $i);
 
  if ($DEBUG) {
    print "End: $j\n";
  }

  $out = substr($out, $i, $j-$i);

  $k = index($out, "\.TODAY\.\.\.");
  if($k == -1) {
     $k = index($out, "\.TONIGHT\.\.\.");
  }
  if($k == -1) {
     $k = index($out, "  \.");
  }
  $out = substr($out, $k, $j-$i-$k);
  $out =~ y/A-Z/a-z/;

  $out =~ s/\.\.\.small craft advisory\.\.\.//g;

  # Convert the times
  $out =~ s/\.today\.\.\./<B>Today:<\/B> /g;
  $out =~ s/\.tonight\.\.\./<B>Tonight:<\/B> /g;
  $out =~ s/\.sun\.\.\./<B>Sunday:<\/B> /g;
  $out =~ s/\.mon\.\.\./<B>Monday:<\/B> /g;
  $out =~ s/\.tue\.\.\./<B>Tuesday:<\/B> /g;
  $out =~ s/\.wed\.\.\./<B>Wednesday:<\/B> /g;
  $out =~ s/\.thu\.\.\./<B>Thursday:<\/B> /g;
  $out =~ s/\.fri\.\.\./<B>Friday:<\/B> /g;
  $out =~ s/\.sat\.\.\./<B>Saturday:<\/B> /g;
  $out =~ s/\.sun night\.\.\./<B>Sunday Night:<\/B> /g;
  $out =~ s/\.mon night\.\.\./<B>Monday Night:<\/B> /g;
  $out =~ s/\.tue night\.\.\./<B>Tuesday Night:<\/B> /g;
  $out =~ s/\.wed night\.\.\./<B>Wednesday Night:<\/B> /g;
  $out =~ s/\.thu night\.\.\./<B>Thursday Night:<\/B> /g;
  $out =~ s/\.fri night\.\.\./<B>Friday Night:<\/B> /g;
  $out =~ s/\.sat night\.\.\./<B>Saturday Night:<\/B> /g;
  $out =~ s/\.independence day\.\.\./<B>Independence Day:<\/B> /g;
  #$out = join("", $out, "<BR>\n");

  # Convert the wind/swell directrions
  $out =~ s/\.\.\./ \.\.\. /g;
  $out =~ s/ n / N /g;
  $out =~ s/ nw / NW /g;
  $out =~ s/ w / W /g;
  $out =~ s/ sw / SW /g;
  $out =~ s/ s / S /g;
  $out =~ s/ se / SE /g;
  $out =~ s/ e / E /g;
  $out =~ s/ ne / NE /g;
  $out =~ s/ n\./ N\. /g;
  $out =~ s/ nw\. / NW\. /g;
  $out =~ s/ w\. / W\. /g;
  $out =~ s/ sw\. / SW\. /g;
  $out =~ s/ s\. / S\. /g;
  $out =~ s/ se\. / SE\. /g;
  $out =~ s/ e\. / \E. /g;
  $out =~ s/ ne\. / NE\. /g;

  # Capitalize commonly referenced names
  $out =~ s/florence/Florence/g;
  $out =~ s/newport/Newport/g;
  $out =~ s/cape lookout/Cape Lookout/g;
  $out =~ s/cape blanco/Cape Blanco/g;
  $out =~ s/cascade head/Cascade Head/g;
  $out =~ s/cape/Cape/g;
  $out =~ s/disappointment/Disappointment/g;
  $out =~ s/shoalwater/Shoalwater/g;
  $out =~ s/washington/Washington/g;
  $out =~ s/oregon/Oregon/g;
  $out =~ s/california/California/g;

  # Convert some abreviations
  $out =~ s/tstms/thunderstorms/g;

  print($OUTFILE "$out\n");

  close(NWSFILE);
  system "rm -f /tmp/marine.PDX";
}
    

# Arg 1 is the file handler to output to
sub getWAM {
  local($OUTFILE) = $_[0];

  # Get the current and 24-out WAM
  if ($DEBUG) { print "Getting WAM\n"; }

  print($OUTFILE "<B>Current:<\/B><BR>\n");
  if (!https_save($WAM_Current_URL, "/tmp/wam00.gif")) {
      system "rm -f /tmp/wam00.gif";
      system "cp shim.gif ww3-thumb.gif";
      if ($DEBUG) {
          print($OUTFILE "<I>Couldn't retrieve WW3 Image<\/I><BR>\n");
      }
  } 
  else {
      # Old crop was 379x232+249+121 
      system "$convert -crop 420x250+240+200 +repage -border 1 -bordercolor black /tmp/wam00.gif wam00-nwus.gif";
      
      print($OUTFILE "<IMG SRC=\"wam00-nwus.gif\" ALT=\"WW3 Current Swell Model Image\"><BR>\n");

      # Create a WW3/WAM thumbnail for external use
      system "$convert -scale 190 -crop 140x100+46+3 +repage -border 2 -bordercolor black wam00-nwus.gif ww3-thumb.gif"; 
  }

  print($OUTFILE "<B>24 Hours from now:<\/B><BR>\n");
  if (!https_save($WAM_24hr_URL, "/tmp/wam24.gif")) {
      system "rm -f /tmp/wam24.gif";
      if ($DEBUG) {
          print($OUTFILE "<I>Couldn't retrieve WW3 Image<\/I><BR>\n");
      }
  } 
  else {
      system "$convert -crop 420x250+240+200 +repage -border 1 -bordercolor  black /tmp/wam24.gif wam24-nwus.gif";
      print($OUTFILE "<IMG SRC=\"wam24-nwus.gif\" ALT=\"WW3 24-Hour Swell Model Image\"><BR>\n");
  }

  print($OUTFILE "<IMG SRC=wam_key.gif ALT=\"WAM Key\"><P>\n");

  system "rm -f /tmp/wam00.gif /tmp/wam24.gif";
}


sub getTide {
  local($OUTFILE) = $_[0];
  local($tide,$dummy1,$date,$time,$ampm, $dummy2, $height);

  print($OUTFILE "<TABLE BORDER>\n");
  print($OUTFILE "<TR ALIGN=LEFT><TD><\/TD><TD><FONT SIZE=-1><B>Date<\/B><\/FONT><\/TD><TD><FONT SIZE=-1><B>Time<\/B><\/FONT><\/TD><TD><FONT SIZE=-1><B>Height<\/B><BR>(ft)<\/FONT><\/TD><\/TR>\n");

  open(TIDEFILE, "$xtide -loctz -text 4 -nowarn -location 'South Beach' |") || return;;
  while(<TIDEFILE>) {
    if(/Tide/) {
      ($tide,$dummy1,$date,$time,$ampm, $dummy2, $height) = 
	split(" ", $_);
      $date = substr($date, 5);
      if($ampm eq "AM") {
        $ampm = "a";
      } else {
        $ampm = "p";
      }
      $time = join("", $time, $ampm);
      $time =~ y/A-Z/a-z/;

      print($OUTFILE "<TR ALIGH=LEFT><TD><FONT SIZE=-1><B>$tide<\/B><\/FONT><\/TD><TD><FONT SIZE=-1>$date<\/FONT><\/TD><TD><FONT SIZE=-1>$time<\/FONT><\/TD><TD><FONT SIZE=-1>$height<\/FONT><\/TD><\/TR>\n");
    }
  }
  print($OUTFILE "<\/TABLE><BR>\n");
  close(TIDEFILE);

  # Tide image
  system "$xtide -loctz -nowarn -graph -skinny -gstretch 0.3 -geometry 150x150 -ppm /tmp/xtide.ppm -location 'South Beach'";
  
  system "$convert -crop 150x115+0+35 +repage /tmp/xtide.ppm xtide.gif";
  system "rm -f /tmp/xtide.ppm";

  print($OUTFILE "<CENTER><IMG SRC=\"xtide.gif\" ALT=\"Tide Image\"><\/CENTER><BR>\n");

}


# Arg 1 is the file handler to output to
sub getWind {
  local($OUTFILE) = $_[0];
  local($buoynum) = 0;
  local($ready) = 0;
  local($wdir,$wspd,$wgst);

  if ($DEBUG) { print "Getting Wind Buoys\n"; }

  print($OUTFILE "<TABLE BORDER>\n");
  print($OUTFILE "<TR ALIGN=LEFT><TD><\/TD><TD><FONT SIZE=-1><B>Dir<\/B><\/FONT><\/TD><TD><FONT SIZE=-1><B>Speed<\/B><BR>(kts)<\/FONT><\/TD><TD><FONT SIZE=-1><B>Peak<\/B><BR>(kts)<\/FONT><\/TD><\/TR>\n");

  foreach $b (@Wind_Buoys_List)
    {
      $URL = sprintf("%s%s.txt", $Wind_Buoys_Data_URL, $b);
      if (!https_save($URL, "/tmp/$b.txt")) {
         if ($DEBUG) { print "Failed to get Wind Buoy: $URL\n"; }
	  system "rm -f /tmp/$b.txt";
	  next;
      }

      if ($DEBUG) { print "Reading Wind Buoy: $URL\n"; }

      open(BUOYFILE,"</tmp/$b.txt") || return;
      $ready = 0;
      while (<BUOYFILE>) {
	if($ready==1) {
	  @buoy_data = split(" ", $_);

	  # Check data time
	  $data_time = &timegm( 0,
				0,
				int($buoy_data[3]),
				int($buoy_data[2]),
				int($buoy_data[1])-1,
				int($buoy_data[0])-1900,
				0, 0, 0 );

	  if(&check_time($data_time, 24)) {
	      $wdir = $buoy_data[5];
	      $wspd = $buoy_data[6];
	      $wgst = $buoy_data[7];
	      if ($DEBUG) { print "\t$wspd\t$wgst\t$wdir\n"; }

	      if($wspd eq "MM" || $wspd eq "N/A" || $wspd eq "0") {
		  $wspd = "--";
	      } else {
		  $wspd = sprintf("%.1f", &mps2knots($wspd));
	      }
	      if($wgst eq "MM" || $wgst eq "N/A" || $wgst eq "0")
                  { $wgst = "--"; }
	      else { 
                $wgst = sprintf("%.1f", &mps2knots($wgst));
             }
	      
	      if($wdir eq "MM") { $wdir = "--"; }
	      else { $wdir = &convertDir($wdir); }
	  }	  
	  else {
             if ($DEBUG) { print "Failed to parse\n"; }
	      $wspd = "--";
	      $wgst = "--";
	      $wdir = "--";
	  }

	  print($OUTFILE "<TR ALIGN=LEFT><TD><FONT SIZE=-1><B>$Wind_Buoys_Names{$b}<\/B><\/FONT><\/TD>\n");
	  print($OUTFILE "<TD><FONT SIZE=-1>$wdir<\/FONT><\/TD><TD><FONT SIZE=-1>$wspd<\/FONT><\/TD><TD><FONT SIZE=-1>$wgst<\/FONT><\/TD><\/TR>\n");

	  close(BUOYFILE);
	  last;
	}	  

	if(/#yr/) {
	  $ready = 1;
	}
      }

      system "rm -f /tmp/$b.txt";
    }
  
  print($OUTFILE "<\/TABLE>\n");
}


# Arg 1 is the file handler to output to
sub getBuoys {
  local($OUTFILE) = $_[0];
  local($buoynum) = 0;
  local($ready) = 0;
  local($wvht,$wvper,$wvdir);

  if ($DEBUG) { print "Getting Buoys\n"; }

  print($OUTFILE "<TABLE BORDER>\n");
  print($OUTFILE "<TR ALIGN=LEFT><TD><\/TD><TD><B><FONT SIZE=-1>Height<\/FONT><\/B><\/TD><TD><B><FONT SIZE=-1>Period<\/FONT><\/B><\/TD><\/TR>\n");

  foreach $b (@Buoys_List)
    {
      $URL = sprintf("%s%s.spec", $Buoys_Data_URL, $b);
      if (!https_save($URL, "/tmp/$b.txt")) {
	  system "rm -f /tmp/$b.txt";
	  next;
      }

      open(BUOYFILE,"</tmp/$b.txt") || return;
      $ready = 0;
      while (<BUOYFILE>) {
	if($ready==1) {
	  @buoy_data = split(" ", $_);

	  # Check data time
	  $data_time = &timegm( 0,
				0,
				int($buoy_data[3]),
				int($buoy_data[2]),
				int($buoy_data[1])-1,
				int($buoy_data[0])-1900,
				0, 0, 0 );

	  if(&check_time($data_time, 24)) {
	      $wvht = $buoy_data[6];
	      $wvper = $buoy_data[7];
	      $wvdir = $buoy_data[10];
	      
	      if($wvht eq "0") {
		  $wvht = "--";
	      } else {
		  $wvht = sprintf("%.1f", &meters2feet($wvht));
	      }
	      if($wvper eq "MM" || $wvper eq "N/A" || $wvper eq "0")
                  { $wvper = "--"; }
	      else { $wvper = "$wvper"; }
	      
	      if($wvdir eq "MM") { $wvdir = "--"; }
	      else { $wvdir = &convertDir($wvdir); }
	  }	  
	  else {
	      $wvht = "--";
	      $wvper = "--";
	      $wvdir = "--";
	  }

	  $out = sprintf("<TR ALIGN=LEFT><TD><B><FONT SIZE=-1>$Buoys_Names{$b}<\/FONT><\/B><\/TD><TD><FONT SIZE=-1>$wvht ft<\/FONT><\/TD><TD><FONT SIZE=-1>$wvper s<\/FONT><\/TD><\/TR>\n");
	  print($OUTFILE $out);

	  close(BUOYFILE);
	  last;
	}	  

	if(/#yr/) {
	  $ready = 1;
	}
      }

      system "rm -f /tmp/$b.txt";
    }
  
  print($OUTFILE "<\/TABLE>\n");
}


#links{row,col}  from 1 to $links_maxrow and 1 to $links_maxcol
$links_maxrow = 6;
$links_maxcol = 2;
$links_txt{1,1} = "Oregon Surfrider";
$links_URL{1,1} = "http:\/\/www.surfrider.org\/oregon\/";
$links_txt{2,1} = "Oregon Surf Page";
$links_URL{2,1} = "http:\/\/www.oregonsurf.com\/";
$links_txt{3,1} = "Oregon Climate Service";
$links_URL{3,1} = "http:\/\/www.ocs.orst.edu\/";
$links_txt{4,1} = "National Weather Service";
$links_URL{4,1} = "http:\/\/www.wrh.noaa.gov\/pqr\/marine.php";
$links_txt{5,1} = "ORST Surf Page";
$links_URL{5,1} = "http:\/\/nwprtsrf.oce.orst.edu:8080\/nwprtsrf\/surf.html";
$links_txt{6,1} = "buoyweather.com";
$links_URL{6,1} = "http:\/\/buoyweather.com";
$links_txt{1,2} = "Coastal Marine Forcast";
$links_URL{1,2} = $NWS_Coastal_Primary_URL;
$links_txt{2,2} = "Buoy Reports";
$links_URL{2,2} = $Buoys_Index_URL;
$links_txt{3,2} = "Navy WW3";
$links_URL{3,2} = $WAM_Index_URL;
$links_txt{4,2} = "Wind Observations";
$links_URL{4,2} = $NWS_Wind_Primary_URL;
$links_txt{5,2} = "Tide Predictor";
$links_URL{5,2} = $Tide_URL;
$links_txt{6,2} = "Magic Seaweed"; 
$links_URL{6,2} = "http:\/\/magicseaweed.com";


sub getLinks {
  local($OUTFILE) = $_[0];

  print($OUTFILE "<TABLE>\n");

  for($i=1;$i<=$links_maxrow;$i++) {
    print($OUTFILE "<TR>\n");
    for($j=1;$j<=$links_maxcol;$j++) {
      print($OUTFILE "<TD><A HREF=\"$links_URL{$i,$j}\"><FONT SIZE=-2>$links_txt{$i,$j}<\/FONT><\/A><\/TD>\n");
    }
    print($OUTFILE "<\/TR>\n");
  }
  print($OUTFILE "<\/TABLE>\n");

}


sub SurfCheck {
  open(SURFCHECKFILE, ">surfcheck-tmp.html") || die;
  
  print(SURFCHECKFILE "<HTML>\n"); 
  print(SURFCHECKFILE "<HEAD>\n");
  print(SURFCHECKFILE "<TITLE>One-Stop Oregon Surf Check<\/TITLE>\n");
  print(SURFCHECKFILE "<META HTTP-EQUIV=\"Refresh\" CONTENT=3600>\n");
  print(SURFCHECKFILE "<META HTTP-EQUIV=\"Expires\" CONTENT=\"0\">\n");
  print(SURFCHECKFILE "<\/HEAD>\n"); 
  print(SURFCHECKFILE "<BODY BGCOLOR=\"#FFFFFF\">\n");
  print(SURFCHECKFILE "<CENTER><TABLE WIDTH=640 BORDER=0><TR><TD>\n");
  print(SURFCHECKFILE "<TABLE WIDTH=640>\n<TR>");
  print(SURFCHECKFILE "<TD WIDTH=450><FONT SIZE=+3><IMG SRC=\"sctitle.gif\" ALT=\"Oregon Surf Check\"><\/FONT><\/TD>\n");
  print(SURFCHECKFILE "<TD WIDTH=190><FONT SIZE=+2>Data Updated:<\/FONT><BR>");
  print(SURFCHECKFILE &updateTime());
  print(SURFCHECKFILE "<BR><A HREF=\"surfcheckfaq.html\">SurfCheck FAQ<\/A>\n");
  print(SURFCHECKFILE "<\/TD><\/TR><\/TABLE><HR>\n");
  #print(SURFCHECKFILE "<B><I><FONT COLOR=\"#FF0000\" SIZE=+2>Experiencing Technical Difficulties</FONT></I></B><HR>\n");

  print(SURFCHECKFILE "<TABLE><TR VALIGN=TOP><TD WIDTH=190>\n");

  print(SURFCHECKFILE "<B>Buoy Reports<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$Buoys_Index_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR>\n");
  &getBuoys(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 

  print(SURFCHECKFILE "<B>ORST Microseismometer<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$HMSC_Data_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR>\n");
  &getHMSC(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 

  print(SURFCHECKFILE "<B>Wind<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$Buoys_Index_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR>\n");
  &getWind(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 

  print(SURFCHECKFILE "<B>Tides at Newport<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$Tide_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR>\n");
  &getTide(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 

  print(SURFCHECKFILE "<\/TD><TD WIDTH=450>");


  print(SURFCHECKFILE "<B>National Weather Service Forcast<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$NWS_Coastal_Primary_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR><BR>\n"); 
  &getNWSInfo(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 


  print(SURFCHECKFILE "<B>Navy Wave Watch 3 Swell Models (WW3)<\/B>\n");
  print(SURFCHECKFILE "<A HREF=$WAM_Index_URL><IMG BORDER=0 SRC=\"linkarrow.gif\" ALT=\"[Source Data]\"><\/A><BR>\n");
  &getWAM(SURFCHECKFILE);
  print(SURFCHECKFILE "<P>\n"); 


  print(SURFCHECKFILE "<CENTER><B>Links<\/B><BR>\n");
  &getLinks(SURFCHECKFILE);
  print(SURFCHECKFILE "<\/CENTER><P>\n");
 

  print(SURFCHECKFILE "<\/TD><\/TR><\/TABLE>");
  print(SURFCHECKFILE "<HR><IMG SRC=\"linkarrow.gif\"> clickable links to source data<P><I><A HREF=\"mailto:kurtwindisch\@yahoo.com\">kurtwindisch\@yahoo.com<\/A><\/I>\n");
  print(SURFCHECKFILE "<\/CENTER><\/TD><\/TR><\/TABLE>\n");
  print(SURFCHECKFILE "<\/BODY><\/HTML>\n");
}


sub updateTime {
#  return(&ctime($^T));
 
  # Hacked out of ctime.pl
    local($time) = $^T;
    local($[) = 0;
    local($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst);

    # Convert eastern to pacifc ... hack hack hack
    $time -= $ServerOffset;

    @DoW = ('Sun','Mon','Tue','Wed','Thu','Fri','Sat');
    @MoY = ('Jan','Feb','Mar','Apr','May','Jun',
            'Jul','Aug','Sep','Oct','Nov','Dec');

    # Determine what time zone is in effect.
    # Use GMT if TZ is defined as null, local time if TZ undefined.
    # There's no portable way to find the system default timezone.

    $TZ = defined($ENV{'TZ'}) ? ( $ENV{'TZ'} ? $ENV{'TZ'} : 'GMT' ) : '';
    ($sec, $min, $hour, $mday, $mon, $year, $wday, $yday, $isdst) =
        ($TZ eq 'GMT') ? gmtime($time) : localtime($time);

    # Hack to deal with 'PST8PDT' format of TZ
    # Note that this can't deal with all the esoteric forms, but it
    # does recognize the most common: [:]STDoff[DST[off][,rule]]

    if($TZ=~/^([^:\d+\-,]{3,})([+-]?\d{1,2}(:\d{1,2}){0,2})([^\d+\-,]{3,})?/){
        $TZ = $isdst ? $4 : $1;
    }
    $TZ .= ' ' unless $TZ eq '';

    $year += 1900;

    # Ugly hack to up for the fact that this is running on a server in
    # the eastern time zone for presentation to us left coasters.
    # Added US/Pacific here and subtraced 3hrs from the function parameter.
    sprintf("%s %s %2d %2d:%02d US/Pacific\n",
      $DoW[$wday], $MoY[$mon], $mday, $hour, $min);
  
}

# MAIN
&SurfCheck();
