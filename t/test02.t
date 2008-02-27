# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl HTML-CTPP2.t'

#########################

# change 'tests => 1' to 'tests => last_test_to_print';

use Test::More tests => 15;
BEGIN { use_ok('HTML::CTPP2') };

use strict;

my $T = new HTML::CTPP2();
ok( ref $T eq "HTML::CTPP2", "Create object.");

my @IncludeDirs = ("./", "examples");

ok( $T -> include_dirs(\@IncludeDirs) == 0);

my $Bytecode = $T -> parse_template("hello.tmpl");
ok( ref $Bytecode eq "HTML::CTPP2::Bytecode", "Create object.");

# Test base methods
my @methods = qw/save/;
can_ok($Bytecode, @methods);

my $Code = $Bytecode -> save("hello.ct2");
ok($Code == 0);

undef $Bytecode;
$Bytecode = $T -> load_bytecode("hello.ct2");
ok( ref $Bytecode eq "HTML::CTPP2::Bytecode", "Create object.");

my %H = ("world" => "beautiful World");
ok( $T -> param(\%H) == 0);

my $Result = $T -> output($Bytecode);
ok( $Result eq "Hello, beautiful World!\n\n");

$T -> reset();
ok( $T -> dump_params() eq "HASH {\n}\n");

$Result = $T -> output($Bytecode);
ok( $Result eq "Hello, !\n\n");

my %HH = ("world" => "awfull World");
ok( $T -> param(\%HH) == 0);

ok( $T -> dump_params() eq "HASH {\n    world => awfull World\n}\n");

$Result = $T -> output($Bytecode);
ok( $Result eq "Hello, awfull World!\n\n");

%HH = ("world" => "World");
$T -> param(\%HH);
$Result = $T -> output($Bytecode);
ok( $Result eq "Hello, World!\n\n");

