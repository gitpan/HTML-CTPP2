use 5.008001;
use strict;
use ExtUtils::MakeMaker;

my @IncludeDirs = ($ENV{'CTPP2_INCLUDE'},
                   "/usr/local/include/ctpp2",
                   "/usr/include/ctpp2",
                   "/opt/include/ctpp2",
		   "/opt/REKIctpp2/include/ctpp2",
                   "/usr/local/ctpp2/include");

my @LibDirs     = ($ENV{'CTPP2_LIB'},
                   "/usr/local/lib",
                   "/usr/lib",
                   "/opt/lib",
		   "/opt/REKIctpp2/lib",
                   "/usr/local/ctpp2/lib");

sub NeedToInstallCTPP
{
	my $Error = shift;
	warn $Error .
	"\nYou should install CTPP2 library first!\n" .
	"Sources of CTPP2 available here: http://ctpp.havoc.ru/download/\n".
	"You may also define the CTPP2_INCLUDE and CTPP2_LIB environment variables.";
	exit;
}

sub SearchDir
{
	my $File = shift;
	foreach (@_)
	{
		return $_ if (-e "$_/$File");
	}
return undef;
}

print "perl thinks the current OS is '$^O'\n";

my $CXX = 'g++';
my $CC  = 'gcc';
my $STDCPP = '-lstdc++';
if ($^O eq 'solaris') { $CXX = 'CC'; $CC = 'CC'; $STDCPP = '-lCstd'; }

my $CTPP2IncludeDir = SearchDir("CTPP2.hpp", @IncludeDirs);
unless ($CTPP2IncludeDir) { NeedToInstallCTPP("Cannot find header file CTPP2.hpp"); exit; }

my $CTPP2LibDir     = SearchDir("libctpp2.so.2", @LibDirs);
unless ($CTPP2LibDir) { NeedToInstallCTPP("Cannot find shared library file libctpp2.so"); exit; }

WriteMakefile(
    'NAME'		=> 'HTML::CTPP2',
    'VERSION_FROM' 	=> 'lib/HTML/CTPP2.pm',
    'LIBS'		=> "-L$CTPP2LibDir -L/usr/lib -lm -lctpp2 $STDCPP",
    'DEFINE'		=> '-fexceptions -O2 -Wno-deprecated ',
    'INC'		=> "-I$CTPP2IncludeDir -I/usr/include -I/usr/local/include -I. ",
    'CC'		=> $CXX,
    'LD'		=> $CC,
    'XSOPT'		=> '-C++',
    'clean'		=> { 'FILES' => '*.ct2' },
    'TYPEMAPS'		=> ['perlobject.map'],
    'AUTHOR'            => 'Andrei V. Shetuhin <reki@reki.ru>'
);

