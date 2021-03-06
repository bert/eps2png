# Makefile.PL -- Makefile for eps2png
# Author          : Johan Vromans
# Created On      : Sat Jun  6 16:08:33 1998
# Last Modified By: Johan Vromans
# Last Modified On: Thu Jan  2 15:18:26 2020
# Update Count    : 65
# Status          : Released

# Ease the life of the CPAN testers.
exit 0 if $ENV{AUTOMATED_TESTING} && $] < 5.010001;

use strict;
use warnings;
use Config;
# EU::MM 6.5503 is the first version to understand *_REQUIRES.
use ExtUtils::MakeMaker 6.5503;

my @scripts = qw( eps2png );
my $usrbin = "/usr/bin";
my $installscript = $Config{installscript};

print STDERR <<EOD unless $installscript eq $usrbin;

WARNING: This Makefile will install user accessible scripts.
The location for these scripts is $installscript.
You may consider to pass INSTALLSCRIPT=$usrbin (or some other
convenient location) to "make install".
EOD

print STDERR <<EOD;

IMPORTANT: This program requires Ghostscript and may require the
Portable Bitmap package (PBM) for additional conversions.

IMPORTANT: Due to ongoing development of the Ghostscript output
drivers, some tests may fail. See README for details.

EOD

$ENV{LC_ALL} = "C";
my $gs = `gs --help`;
unless ( $gs =~ /^available devices:/im ) {
    warn("Ghostscript not found. Cannot continue\n");
    exit 0;
}

foreach my $type ( qw(pngmono pnggray png16 png256 pngalpha jpeggray) ) {
    next if $gs =~ / $type( |$)/m;
    warn("No Ghostscript driver for $type. You won't be able to use these.\n");
}
foreach my $type ( qw(png16m jpeg) ) {
    next if $gs =~ / $type( |$)/m;
    warn("No Ghostscript driver for $type. Some tests will fail.\n");
}
my $needpbm = 0;
foreach my $type ( qw(gif gifmono) ) {
    next if $gs =~ / $type( |$)/m;
    warn("No Ghostscript driver for $type. PBM fallback required.\n");
    $needpbm = 1;
}

my $name = 'eps2png';
my $master = "src/${name}.pl";
my $version = MM->parse_version($master);
unless ( -f "${name}.spec" ) {
    open( my $fd, ">", "${name}.spec" );
    print $fd "Placeholder, will be overwritten by Makefile.PL.\n";
    close($fd);
}

WriteMakefile(
    NAME                => $name,
    AUTHOR              => 'Johan Vromans <jv@cpan.org>',
    VERSION	        => $version,
    ABSTRACT_FROM       => $master,
    LICENSE		=> 'perl',
    PL_FILES            => {},
    EXE_FILES		=> [ map { "script/$_" } @scripts ],
    MIN_PERL_VERSION	=> '5.010000',

    CONFIGURE_REQUIRES => {
        "ExtUtils::MakeMaker" => 6.5503,
    },

#   BUILD_REQUIRES => {
#   },

    TEST_REQUIRES  => {
      'Test::More'  => 0,
    },

    META_MERGE => {
      resources    => {
        repository => {
          type => 'git',
	   web  => "https://github.com/sciurius/${name}",
	   url  => "https://github.com/sciurius/${name}.git",
	 },
	 bugtracker => "https://github.com/sciurius/${name}/issues",
	},
	'meta-spec' => {
	  version => '2',
	  url     => 'https://metacpan.org/pod/CPAN::Meta::Spec',
	},
      provides => {
	eps2png => { file => "script/${name}", version => $version },
      }
    }
);

warn("Creating script\n");
open(my $src, "<", "src/${name}.pl")
  or die("src/${name}.pl: $!\n");
open(my $dst, ">", "script/${name}")
  or die("script/${name}: $!\n");

while ( <$src> ) {
    s/my \$use_pbm = .;/my \$use_pbm = $needpbm;/;
    print { $dst } $_;
}

close($dst);
close($src);

WriteSpecfile( $name, $version );

1;

use POSIX 'strftime';

sub WriteSpecfile {
    my $name    = shift;
    my $version = shift;
    my @tm = localtime;

    vcopy( _tag	    => "RPM spec file",
	   _dst	    => "$name.spec",
	   pkgname  => $name,
	   version  => $version,
	   rpmdate  => strftime("%a %b %e %Y", @tm),
	 );
}

sub vcopy {
    my (%ctrl) = @_;

    $ctrl{_src} ||= $ctrl{_dst} . ".in";

    return unless open(my $fh, "<", $ctrl{_src});

    print("Writing ", $ctrl{_tag}, "...\n") if $ctrl{_tag};

    my $newfh;
    open ($newfh, ">", $ctrl{_dst})
      or die($ctrl{_dst}, ": $!\n");

    my $pat = "(";
    foreach ( grep { ! /^_/ } keys(%ctrl) ) {
	$pat .= quotemeta($_) . "|";
    }
    chop($pat);
    $pat .= ")";

    $pat = qr/\[\%\s+$pat\s+\%\]/;

    while ( <$fh> ) {
	s/$pat/$ctrl{$1}/ge;
	print { $newfh } $_;
    }
    close($newfh);
}
