use 5.008001;
use ExtUtils::MakeMaker;

# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    'NAME'		=> 'HTML::CTPP2',
    'VERSION_FROM' 	=> 'lib/HTML/CTPP2.pm', # finds $VERSION
    'LIBS'		=> ['-L/usr/local/lib -L/usr/lib -lm -lctpp2 -lstdc++'],
    'DEFINE'		=> '-fexceptions -O2 -Wno-deprecated ',     # e.g., ''
    'INC'		=> '-I/usr/include/ctpp2 -I/usr/local/include/ctpp2 -I/usr/include -I/usr/local/include -I. ',
    'CC'		=> 'g++',
    'LD'		=> 'gcc',
    'XSOPT'		=> '-C++',
    'TYPEMAPS'		=> ['perlobject.map'],
    'AUTHOR'            => 'Andrei V. Shetuhin <reki@reki.ru>'
);
