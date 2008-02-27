package HTML::CTPP2;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK);

require Exporter;
require DynaLoader;
require AutoLoader;

@ISA = qw(Exporter DynaLoader);

@EXPORT = qw(

);

$VERSION = '2.0.4';

bootstrap HTML::CTPP2 $VERSION;

push @HTML::Template::ISA,       qw/HTML::CTPP2/;
push @HTML::Template::Expr::ISA, qw/HTML::CTPP2/;

# Autoload methods go after =cut, and are processed by the autosplit program.
1;
__END__;

=head1 NAME

  HTML::CTPP2 - Perl interface for CTPP2 library

=head1 SYNOPSIS

  First you should make template, file `hello.tmpl`:

  Foo: <TMPL_var foo>
  <TMPL_if array>
      Here is loop body:
      <TMPL_loop array>
          Key: <TMPL_var key>
      </TMPL_loop>
  </TMPL_if>

  Now create PERL script:

  #!/usr/bin/perl -w
  use strict;
  use HTML::CTPP2;
  my $T = new HTML::CTPP2();

  # Parse template
  my $Bytecode = $T -> parse_template("hello.tmpl");

  # Fill parameters
  my %H = ("foo" => "bar", array => [ { "key" => "first" }, { "key" => "second"} ]);

  $T -> param(\%H);

  my $Result = $T -> output($Bytecode);

  Now check output:
  Foo: bar
      Here is loop body:
          Key: first
          Key: second

=head1 DESCRIPTION

  This module is very similar to well-known Sam Tregar's HTML::Template but works
  in 22 - 25 times faster and contains extra functionality.
  CTPP2 template language dialect contains 9 operators: <TMPL_var>, <TMPL_if>,
  <TMPL_elsif>, <TMPL_else>, <TMPL_unless>, <TMPL_loop>, <TMPL_udf>, <TMPL_include>
  and <TMPL_comment>.

=head1 THE TAGS

  In order to simplify the make-up, all operators names are case insensitive,
  that is why the notifications such as: <TMPL_var , <TmPl_VaR , <tmpl_VAR
  are equal.

  BUT the names of variables are case sensitive, that's why for example:
  <TMPL_var ABC>, <TMPL_var abc>, <TMPL_var Abc> are not in equal state.

  Parameters, which names starting with a symbol of underlining
  (for example __FIRST__) are reserved names and should NOT be used
  by the developer. Variable names can be composed of letters, numbers,
  and underscores (_). Every variable name in CTPP must start with a letter.

=head2 TMPL_var

  <TMPL_var VAR_NAME>, <TMPL_udf VAR_NAME> - Direct parameter output.

  In CTPP template engine two types of variables are defined: local and global.
  The sense of these two concepts is completely equal with a similar idea
  in the other algorithmic languages such as C++ & Perl.

  For variable output use operator <TMPL_var VAR_NAME>

  Example 1.1
  Template: "Hello, <b><TMPL_var username></b>!"
  Parameter: username => "Olga"
  Output: "Hello, Olga!"

  You can use user defined functions to make a variable output.

  Example 1.2
  Template: "<a href="/index.cgi?username=<TMPL_var URLESCAPE(username)>">"
  Parameter: username => "������" (string in non-ascii7 character set)
  Output: "<a href="/index.cgi?username=%C0%ED%E4%F0%E5%E9">"

=head2 TMPL_if, TMPL_unless

  These operators impose condition on your template output, it depends on the
  result of logical expression placed to the right of the operator's body.

  CTPP defines four operators of condition: <TMPL_if LOGICAL_EXPR>,
  <TMPL_elsif LOGICAL_EXPR>, <TMPL_else> and <TMPL_unless LOGICAL_EXPR>.

  Operators evaluates logical expression to the result and according to it
  executes or not the further instructions. You can also use variables
  (local and global) and user defined functions inside of the operator's body.

  Example 2.1

  <TMPL_if LOGICAL_EXPR>
     Some instructions if result has true value.
  <TMPL_elsif OTHER_EXPRESSION>
    Some instructions if result has false value.
  <TMPL_else>
    Else-branch/
  </TMPL_if>

  <TMPL_unless LOGICAL_EXPR1>
    Some instructions if result has false value.
  <TMPL_elsif LOGICAL_EXPR2>
    Some instructions if evaluation result of
    LOGICAL_EXPR2 has true value.
  <TMPL_else>
    Some instructions if result has true value.
  </TMPL_unless>

  The branches of <TMPL_elsif> and <TMPL_else> are not firmly binds,
  it means that the following notification is allowed:
  <TMPL_if LOGICAL_EXPR> Some instructions </TMPL_if>.
  Thus the operator <TMPL_unless differs from the operator <TMPL_if in the
  executing some instructions if the evaluated value is false.

=head2 TMPL_loop

  The loop - The multiple repeating of some pre-defined actions.

  The only type of loops has been defined in CTPP - the forward running over
  through the data array. The operator corresponding with this action looks
  like the following:

  <TMPL_loop MODIFIERS LOOP_NAME>
      The LOOP instructions.
  </TMPL_loop>

  If you evidently put the mark to use context variables in the loop body,
  CTPP inserts seven special variables, called context vars. The names of these
  variables start with the double underline, this fact points to their system
  meaning. Set of values for "context vars":

    * __FIRST__ - sets to "1" during the first loop iteration,
      in other cases not defined.

    * __LAST__ - sets to the last iteration number,
      otherwise is not defined.

    * __INNER__ - accommodates the number from the second to the pre-last
      iteration, otherwise undefined

    * __ODD__ - the number of an odd iteration. For the even one - undefined.

    * __COUNTER__ - the number of current iteration.

    * __EVEN__ - opposite to the __ODD__ variable.

    * __SIZE__ - the whole number of the loop iterations.

    * __CONTENT__ - contains value of current iteration

=head2 TMPL_include

  In some cases it happens to allocate conveniently identical parts in several
  templates (for example, heading or the menu on page) and to place them in one file.

  This is done by operator <TMPL_include filename.tmpl>.

  Example 3.1:
    File `main.tmpl`:
    <TMPL_loop foo>
        <TMPL_include "filename.tmpl">
    </TMPL_loop>

    File filename.tmpl:
       <TMPL_var bar>

  Attention! You CAN NOT place a part of a loop or condition in separate templates.
  In other words, this construction will not work:

  Example 3.2
  File `main.tmpl`:
    <TMPL_if foo>
       <TMPL_include 'abc.tmpl'>

  File `abc.tmpl`:
    </TMPL_if>

=head2 TMPL_comment

  All characters between <TMPL_comment> and </TMPL_comment> are ignored. This is
  useful to comment some parts of template.

=head2 Built-in functions

  There are a variety of situations when you need to represent data according
  to some condition. To simplify the solution of this problem CTPP support
  Built-in Functions. ou can call them from the bodies of <TMPL_if, <TMPL_unless,
  <TMPL_var and <TMPL_udf operators. The following example shows how to call
  Built-in function:

  <TMPL_var HTMLESCAPE(name)>

  <TMPL_if IN_SET(name, 1, 2, 3)>
    Variable "name" is set to "1", "2" or "3".
  </TMPL_if>

  CTPP2 support following built-in functions:

    * URLESCAPE
    * HTMLESCAPE
    * XMLESCAPE
    * NUM_FORMAT
    * GETTEXT (_)
    * IN_SET
    * HREF_PARAM
    * FORM_PARAM
    * DATE_FORMAT
    * BASE64_ENCODE
    * BASE64_DECODE
    * MD5
    * ICONV
    * VERSION
    * OBJ_DUMP

  Please refer to CTPP2 library documentation to get detailed
  information about these functions.

=head1 METHODS

=head2 HTML::CTPP2() - constructor

  Call new() to create a new HTML::CTPP2 object:

  my $T = new HTML::CTPP2();

=head2 param() - set some parameters

  my %Hash = ( "foo" => "bar", "blahblah" => "clah-clah");
  $T -> param(\%H);

=head2 clear_params(), reset() - reset all the parameters to undef.

  $T -> clear_params();
  or
  $T -> reset();

=head2 output() - returns output as string

  In most situations you can print this directly to standard output:

  print $T -> output($bytecode);

=head2 include_dirs() - set list of include directories

  my @IncludeDirs = ("/home/www/tmpl", "/usr/share/www/common_templates");
  $T -> include_dirs(\@IncludeDirs);

  CTPP parser will search templates in specified directories.

=head2 parse_template() - compile source code of template to CTPP bytecode

  my $bytecode = $T -> parse_template("hello.tmpl");

=head2 load_bytecode() - load precompiled template from specified file

  my $bytecode = $T -> load_bytecode("hello.ct2");

  ATTENTION: you should specify FULL path to precompiled file,
  CTPP DOES NOT uses include_dirs to search bytecode!

=head2 dump_params() - get internal representation of all given parameters.

  print $T -> dump_params();

=head2 save() - save compiled bytecode to file

  Since you have compiled template to bytecode you may store it in file.
  This increases speed of loading template.

  # Parse template
  my $bytecode = $T -> parse_template("hello.tmpl");

  # Save bytecode to binary file
  $bytecode -> save("hello.ct2");

  # Now we can load compiled template without parsing original file
  my $other_bytecode = $T -> load_bytecode("hello.ct2");

=head1 AUTHOR

Andrei V. Shetuhin (reki@reki.ru)

=head1 SEE ALSO

perl(1), HTML::Template(3), HTML::Template::Pro(3)

=head1 WEBSITE

http://ctpp.havoc.ru/

=head1 LICENSE

  Copyright (c) 2006 - 2008 CTPP Team

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions
  are met:
  1. Redistributions of source code must retain the above copyright
     notice, this list of conditions and the following disclaimer.
  2. Redistributions in binary form must reproduce the above copyright
     notice, this list of conditions and the following disclaimer in the
     documentation and/or other materials provided with the distribution.
  4. Neither the name of the CTPP Team nor the names of its contributors
     may be used to endorse or promote products derived from this software
     without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE REGENTS AND CONTRIBUTORS ``AS IS'' AND
  ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
  ARE DISCLAIMED.  IN NO EVENT SHALL THE REGENTS OR CONTRIBUTORS BE LIABLE
  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
  OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
  HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
  LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
  OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
  SUCH DAMAGE.

=cut
