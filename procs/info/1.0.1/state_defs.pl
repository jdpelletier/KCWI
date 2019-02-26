#
#
# MOSFIRE library of scripts
#
# NAME
#	state_prefs.pl
#
# SYNOPSIS
#	
#
# DESCRIPTION
#        Provide common definitions for state variables...
#
# ARGUMENTS
#	 none
#
# OPTIONS
#
# EXAMPLES
#
# ENVIRONMENT VARIABLES
#
# FILES
#
# SERVERS & KEYWORDS
#
# SCRIPTS CALLED
#
# EXIT STATUS
#
# SEE ALSO
#-
#
# Modification History:
#       2002mar01       GDW     Original version (LRIS).
#       2010mar15       MK      Added pane keyword parsing
#       2011-Feb-29   	MK	Modified for use with MOSFIRE
#	2012-Jun-28	GDW	Add csutarg keywords
#       2013-Oct-14     MK      Add targname to mot keywords
#                                this is a little dicey in that targname
#                                if found on multiple sub servers, so we are
#                                making an assumption that targname will 
#                                only be used for the filter wheels.
#------------------------------------------------------------ 

$X::rootname = "$ENV{HOME}/.save_state";

# define default filename...
@buf = split /\s+/, scalar( gmtime);
$day = sprintf("%02d", $buf[2]);
$month = $buf[1];
$year = $buf[4];
$X::save_file_default = "$X::rootname.$year-$month-$day";

# list subsystem keywords...
@X::ccd_keywords  = qw( ITIME SAMPMODE NUMREADS COADDS GROUPS ADDCSUEXT );
@X::info_keywords = qw( OUTDIR FRAMENUM EXTENSION OBJECT OBSERVER);
@X::lamp_keywords = qw( PWSTATA7 PWSTATA8);
#@X::mot_keywords  = qw( OBSMODE MDCNAME TARGNAME );
@X::mot_keywords  = qw( OBSMODE MDCNAME );
@X::fcs_keywords  = qw( );
@X::csu_keywords  = qw( MASKNAME B01POS B02POS B03POS B04POS B05POS B06POS
			B07POS B08POS B09POS B10POS B11POS B12POS B13POS B14POS
			B15POS B16POS B17POS B18POS B19POS B20POS B21POS B22POS
			B23POS B24POS B25POS B26POS B27POS B28POS B29POS B30POS
			B31POS B32POS B33POS B34POS B35POS B36POS B37POS B38POS
			B39POS B40POS B41POS B42POS B43POS B44POS B45POS B46POS
			B47POS B48POS B49POS B50POS B51POS B52POS B53POS B54POS
			B55POS B56POS B57POS B58POS B59POS B60POS B61POS B62POS
			B63POS B64POS B65POS B66POS B67POS B68POS B69POS B70POS
			B71POS B72POS B73POS B74POS B75POS B76POS B77POS B78POS
			B79POS B80POS B81POS B82POS B83POS B84POS B85POS B86POS
			B87POS B88POS B89POS B90POS B91POS B92POS );
@X::csutarg_keywords  = qw( SETUPNAME B01TARG B02TARG B03TARG B04TARG B05TARG B06TARG
			B07TARG B08TARG B09TARG B10TARG B11TARG B12TARG B13TARG B14TARG
			B15TARG B16TARG B17TARG B18TARG B19TARG B20TARG B21TARG B22TARG
			B23TARG B24TARG B25TARG B26TARG B27TARG B28TARG B29TARG B30TARG
			B31TARG B32TARG B33TARG B34TARG B35TARG B36TARG B37TARG B38TARG
			B39TARG B40TARG B41TARG B42TARG B43TARG B44TARG B45TARG B46TARG
			B47TARG B48TARG B49TARG B50TARG B51TARG B52TARG B53TARG B54TARG
			B55TARG B56TARG B57TARG B58TARG B59TARG B60TARG B61TARG B62TARG
			B63TARG B64TARG B65TARG B66TARG B67TARG B68TARG B69TARG B70TARG
			B71TARG B72TARG B73TARG B74TARG B75TARG B76TARG B77TARG B78TARG
			B79TARG B80TARG B81TARG B82TARG B83TARG B84TARG B85TARG B86TARG
			B87TARG B88TARG B89TARG B90TARG B91TARG B92TARG );
@X::mech_keywords = ( @X::mot_keywords, @X::fcs_keywords, @X::tv_keywords);

# define alternate keywords for restore...
%X::modify_keyword = (
		      "OBSMODE" => "SETOBSMODE",
		      "MDCNAME" => "MDCTARGN",
		      "MASKNAME" => "SETUPNAME",
		     );

# we must use BnnTARG instead of BnnPOS when modifying value...
my ($k, $k2);
foreach $k ( @X::csu_keywords) {
  $k2 =  $k;
  $k2 =~ s/POS/TARG/;
  $k2 =~ s/MASKNAME/SETUPNAME/;
  $X::modify_keyword{$k} = $k2;
}

#----------------------------------------
# Show - return keyword values in readable format...
#----------------------------------------
sub Show {
  my( $lib, $keyword) = @_;
  my( $value);
  my( @buf);

  # convert keyword to lowercase for compatibility with SWITCH
  # statement below...
  $keyword = lc($keyword);

  # obtain keyword value, trapping for non-functional keywords...
  $value = `show -s $lib -terse $keyword`;
  chomp( $value);
  return undef unless (defined($value) and $value ne "");

  return $value
}

#----------------------------------------
# doSave - write selected keyword to to save file
#----------------------------------------
sub doSave {
#----------------------------------------
  # passed params...
  my $type = shift;
  my $lib = shift;
  my $list = shift;

  # local keywords...
  my $keyword;
  my $value;

  print SAVEFILE "# BEGIN $type keywords\n";
  foreach $keyword (@$list) {
    $value = &Show( $lib, $keyword);
    &Save( $lib, $keyword, $value) if defined($value);
  }
  print SAVEFILE "# END $type keywords\n";

}

#----------------------------------------
# Save - write data to save file in appropriate format...
#----------------------------------------
sub Save{
  my( $lib, $keyword, $value) = @_;
  return unless defined($value);
  printf SAVEFILE "%-8s %-8s %s\n", $lib, $keyword, $value;
}
1;
