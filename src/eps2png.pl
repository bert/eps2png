#! perl

my $RCS_Id = '$Id$ ';

# Author          : Johan Vromans
# Created On      : Tue Sep 15 15:59:04 1992
# Last Modified By: Johan Vromans
# Last Modified On: Sun Jun  7 13:34:49 1998
# Update Count    : 69
# Status          : Unknown, Use with caution!

################ Common stuff ################

use strict;
use Getopt::Long 2.1;

my $my_package = "Sciurix";

my ($VERSION);
# The next line is for MakeMaker.
($VERSION) = '$ Revision: 1.1 $ ' =~ /: ([\d.]+)/;

my ($my_name, $my_version) = $RCS_Id =~ /: (.+).pl,v ([\d.]+)/;
$my_version .= '*' if length('$Locker$ ') > 12;

################ Program parameters ################

### CONFIG
# Some GhostScript programs can produce GIF directly.
# If not, we need the PBM package for the conversion.
my $use_pbm = 1;		# GhostScript can not produce GIF
### END CONFIG

my $res = 82;			# default resolution
my $scale = 1;			# default scaling
my $mono = 0;			# produce BW images if non-zero
my $format;			# output format
my $gs_format;			# GS output type
my $output;			# output, defaults to STDOUT
my $keep = 0;			# keep intermediate files

my ($verbose,$trace,$test,$debug) = (0,0,0,0);
handle_options ();
unless ( defined $format ) {
    if ( $0 =~ /2(gif|jpg|png)$/ ) {
	set_out_type ($1);
    }
    else {
	set_out_type ('png') unless defined $format;
    }
}
print STDERR ("Producing $format ($gs_format) image.\n") if $verbose;

$trace |= $test | $debug;
$verbose |= $trace;

################ Presets ################

my $TMPDIR = $ENV{"TMPDIR"} || "/usr/tmp";

################ The Process ################

my $ps_file = $TMPDIR . "/cv$$.ps";
my $eps_file;
my $err = 0;

foreach $eps_file ( @ARGV ) {

    unless ( open (EPS, $eps_file) ) {
	print STDERR ("Cannot open $eps_file [$!], skipped\n");
	$err++;
	next;
    }

    my $line = <EPS>;
    unless ( $line =~ /^%!PS-Adobe.*EPSF-/ ) {
	print STDERR ("Not EPS file: $eps_file, skipped\n");
	$err++;
	next;
    }

    unless ( open (PS, '>'.$ps_file) ) {
	print STDERR ("Cannot create $ps_file [$!], $eps_file skipped\n");
	$err++;
	next;
    }

    my $width;
    my $height;

    while ( $line = <EPS> ) {

	# Search for BoundingBox.
	if ( $line =~ /^%%BoundingBox:\s*(.+)\s+(.+)\s+(.+)\s+(.+)/i ) {

	    # Create PostScript code to translate coordinates.
	    print PS ("%!PS\n",
		      "$scale $scale scale\n",
		      0-$1, " ", 0-$2, " translate\n",
		      "($eps_file) run\n",
		      "showpage\n",
		      "quit\n");

	    # Calculate actual width.
	    $width  = $3 - $1;
	    $height = $4 - $2;
	    print STDERR ("$eps_file: x0=$1, y0=$2, w=$width, h=$height")
		if $verbose;
	    # Normal PostScript resolution is 72.
	    $width  *= $res/72 * $scale;
	    $height *= $res/72 * $scale;
	    # Round up.
	    $width  = int ($width + 0.5) + 1;
	    $height = int ($height + 0.5) + 1;
	    print STDERR (", width=$width, height=$height\n") if $verbose;
	    last;
	}
	elsif ( $line =~ /^%%EndComments/i ) {
	    print STDERR ("No bounding box in $eps_file\n");
	    $err++;
	    last;
	}
    }
    close (PS);
    close (EPS);

    my $out_file;
    if ( defined $output ) {
	$out_file = $output;
    }
    elsif ( $eps_file =~ /^(.+).epsf?$/i ) {
	$out_file = "$1.$format";
    }
    else {
	$out_file = $eps_file . ".$format";
    }
    print STDERR ("Creating $out_file\n") if $verbose;

    if ( $format eq 'png' ) {
	mysystem ("gs -q -sDEVICE=".
		  ($mono ? "pngmono" : $gs_format).
		  " -dNOPAUSE -sOutputFile=$out_file ".
		  "-r$res -g${width}x$height $ps_file");
	unlink ($ps_file) unless $keep;
    }
    elsif ( $format eq 'jpg' ) {
	mysystem ("gs -q -sDEVICE=".
		  ($mono ? "jpeggray" : $gs_format).
		  " -dNOPAUSE -sOutputFile=$out_file ".
		  "-r$res -g${width}x$height $ps_file");
	unlink ($ps_file) unless $keep;
    }
    elsif ( $format eq 'gif' ) {
	if ( $use_pbm ) {
	    # Convert to PPM and use some of the PBM converters.
	    my $pbm_file = $TMPDIR . "/cv$$.ppm";
	    mysystem ("gs -q -sDEVICE=".
		      ($mono ? "pbm" : "ppm").
		      " -dNOPAUSE -sOutputFile=$pbm_file ".
		      "-r$res -g${width}x$height $ps_file");
	    # mysystem ("pnmcrop $pbm_file | ppmtogif > $out_file");
	    mysystem ("ppmtogif $pbm_file > $out_file");
	    unlink ($pbm_file, $ps_file) unless $keep;
	}
	else {
	    # GhostScript has GIF drivers built-in.
	    mysystem ("gs -q -sDEVICE=".
		      ($mono ? "gifmono" : "gif8").
		      " -dNOPAUSE -sOutputFile=$out_file ".
		      "-r$res -g${width}x$height $ps_file");
	    unlink ($ps_file) unless $keep;
	}
    }
    else {
	print STDERR ("ASSERT ERROR: Unhandled output type: $format\n");
	exit (1);
    }

    unless ( -s $out_file ) {
	print STDERR ("Problem creating $out_file for $eps_file\n");
	$err++;
    }
}

exit ( $err ? 1 : 0 );

################ Subroutines ################

sub mysystem ($) {
    my ($cmd) = @_;
    print STDERR ("+ $cmd\n") if $trace;
    system ($cmd);
}

sub set_out_type () {
    my ($opt) = lc (shift (@_));
    if ( $opt =~ /^png(mono|gray|16|256|16m)?$/ ) {
	$format = 'png';
	$gs_format = $format.(defined $1 ? $1 : '16m');
    }
    elsif ( $opt =~ /^gif(mono)?$/ ) {
	$format = 'gif';
	$gs_format = $format.(defined $1 ? $1 : '');
    }
    elsif ( $opt =~ /^(jpg|jpeg)(gray)?$/ ) {
	$format = 'jpg';
	$gs_format = 'jpeg'.(defined $2 ? $2 : '');
    }
    else {
	print STDERR ("ASSERT ERROR: Invalid value to set_out_type: $opt\n");
	exit (1);
    }
}

sub handle_options {
    my  ($help) = 0;		# handled locally
    my ($ident) = 0;		# handled locally

    # Process options.
    if ( @ARGV > 0 && $ARGV[0] =~ /^[-+]/ ) {
	usage () 
	  unless GetOptions ('ident'     => \$ident,
			     'verbose'   => \$verbose,
			     'scale=f'   => \$scale,
			     'output=s'  => \$output,
			     'png'       => \&set_out_type,
			     'pngmono'   => \&set_out_type,
			     'pnggray'   => \&set_out_type,
			     'png16'     => \&set_out_type,
			     'png256'    => \&set_out_type,
			     'png16m'    => \&set_out_type,
			     'jpg'       => \&set_out_type,
			     'jpggray'   => \&set_out_type,
			     'jpeg'      => \&set_out_type,
			     'jpeggray'  => \&set_out_type,
			     'gif'       => \&set_out_type,
			     'gifmono'   => \&set_out_type,
			     'mono!'     => \$mono,
			     'res'       => \$res,
			     'pbm!'      => \$use_pbm,
			     'keep!'     => \$keep,
			     'trace'     => \$trace,
			     'help'      => \$help,
			     'debug'     => \$debug)
		&& !$help;
    }
    print STDERR ("This is $my_package [$my_name $my_version]\n")
	if $ident;
    usage () unless @ARGV;
    usage () if @ARGV > 1 && defined $output;
}

sub usage () {
    print STDERR <<EndOfUsage;
This is $my_package [$my_name $my_version]
Usage: $0 [options] file [...]

    -png -pngmono -pnggray -png16 -png256 -png16m
                        produce PNG image
    -jpg -jpggray -jpeg -jpeggray
                        produce JPG image
    -gif -gifmono       produce GIF image
    -[no]mono		monochrome/colour rendition
    -res XXX		resolution (default = $res)
    -scale XXX		scaling factor
    -[no]pbm		GIF only: [do not] convert via pbm format
    -output XXX		output to this file (only one input file)
    -[no]keep		[do not] keep temp files
    -help		this message
    -ident		show identification
    -verbose		verbose information
EndOfUsage
    exit 1;
}
__END__

