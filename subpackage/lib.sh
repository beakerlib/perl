#!/bin/bash
# vim: dict=/usr/share/beakerlib/dictionary.vim cpt=.,w,b,u,t,i,k
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   lib.sh of /CoreOS/perl/Library/subpackage
#   Description: Library of functions regarding perl subpackages
#   Author: Martin Kyral <mkyral@redhat.com>
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#
#   Copyright (c) 2012 Red Hat, Inc. All rights reserved.
#
#   This copyrighted material is made available to anyone wishing
#   to use, modify, copy, or redistribute it subject to the terms
#   and conditions of the GNU General Public License version 2.
#
#   This program is distributed in the hope that it will be
#   useful, but WITHOUT ANY WARRANTY; without even the implied
#   warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR
#   PURPOSE. See the GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public
#   License along with this program; if not, write to the Free
#   Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
#   Boston, MA 02110-1301, USA.
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   library-prefix = perlsub
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 NAME

perl/subpackage

=head1 DESCRIPTION

This library provides a set of functions regarding the perl subpackages.

=cut


# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#   Functions
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

true <<'=cut'
=pod

=head1 FUNCTIONS

=head2 perlsubAssertModuleOrigin

Assert that the given CPAN perl module belongs to (one of) the given package(s). If no packages given,
$PACKAGES and $REQUIRES contents are given instead.

    perlsubAssertModuleOrigin MODULE::Module [perl-MODULE-Module [...]]

=over

=item module

Module name as used in perl code, ie. XML::LibXML etc.

=back

Returns 0 when the module is loaded from file belonging to (one of) the asserted package(s).

=cut

function perlsubAssertModuleOrigin() {
    local perlbin=${PERL_BIN:-perl}
    local module=$1
    shift

    local modfile=$(perlsubGetModulePath $module)


    # if not given explicitly as param, take PKGS from $PACKAGES
    local PKGS=$@
    [ $# -eq 0 ] && PKGS="$PACKAGES $REQUIRES $COLLECTIONS"

    local status=1
    local pkg=""
    local modpackage=$(rpm -qf $modfile)

    local pkg
    for pkg in $PKGS ; do
        local TESTED_RPM=$(rpm -q $pkg) &>/dev/null && \
            if [ "$TESTED_RPM" = "$modpackage" ] ; then
                status=0
                echo $TESTED_RPM
                break
            fi
    done

    rlAssert0 "Module $module should belong to one rpm of: $PKGS" $status

    return $?
}

true <<'=cut'
=pod

=head2 perlsubGetCommonPrefix

prints common 'perl' prefix of the given packages. For "perl-XML-LibXML perl-Archive-Tar" the
output is 'perl', while for 'perl516-XML-LibXML perl516-Archive-Tar' the output is 'perl516'.

    PERLBASE=`perlsubGetCommonPrefix [$PKGS]`

=over

=item PKGS

List of perl subpackages. If none is given, $PACKAGES is processed.

=back

The prefix common for the given perl subpackages.

=cut

perlsubGetCommonPrefix() {
    local PKGS=$PACKAGES
    [ $# -gt 0 ] && PKGS="$@"

#    local pkg
#    for pkg in $PKGS ; do
#        echo $pkg | grep runtime &>/dev/null && continue
#        echo $pkg | grep build &>/dev/null && continue
#        rpm -q --provides $pkg | grep perl | grep '(' | sed 's/(.*//' | sort | uniq | awk '{ print length($0) " " $0; }' | sort -n | cut -d ' ' -f 2- | head -n1
#    done | sort | head -n1
     echo $(rpm -qf --queryformat %{name} $(which perl) | sed 's/-interpreter//')
}

true <<'=cut'
=pod

=head2 perlsubFindCommonPrefix

compatibility alias for perlsubGetCommonPrefix()
=cut

perlsubFindCommonPrefix() {
    perlsubGetCommonPrefix $@
}


true <<'=cut'
=pod

=head2 perlsubFindModulePath

prints the location of the given module in the filesystem.

    MODPATH=`perlsubFindModulePath $MOD`

=over

=item MOD

perl module (eg. "Pod::Man").

=back

The prefix common for the given perl subpackages.

=cut

perlsubGetModulePath() {
    if [ $# -ne 1 ] ; then
        echo "Usage: perlsubGetModulePath Module" >&2
        return 1
    fi
    local perlbin=${PERL_BIN:-perl}
    local module=$1
    shift

    perlsub_update_special_params $module

    local modpath="$( echo $module | sed 's/::/\//g').pm"
    # need to create temporary perl script because of the difficulities 
    local printscript="$perlsub_use_module; print \$INC{\"$modpath\"}"
    local script=$(mktemp)

    echo $printscript > $script
    # get the module path
    local modfile=$($perlbin -M$module $script)
    local RC=$?
    rm $script
    [ $RC -ne 0 ] && return 1
    echo $modfile
    return 0
}

# some modules require special behaviour
# no special configuration file for now
function perlsub_update_special_params(){
    local module="$1"
    case "$1" in
        'CPANPLUS::Dist::MM')
            perlsub_use_module='use CPANPLUS; use CPANPLUS::Dist::MM'
            ;;
        'CPANPLUS::Internals::Constants::Report')
            perlsub_use_module='use CPANPLUS; use CPANPLUS::Internals::Constants::Report'
            ;;
        'Math::BigInt::CalcEmu')
            perlsub_use_module='use Math::BigInt; use Math::BigInt::CalcEmu'
            ;;
        'O')
            perlsub_use_module='use O (Deparse)'
            ;;
         'Pod::Simple::Debug')
            perlsub_use_module='use Pod::Simple::Debug (0)'
            ;;
         'autouse')
            perlsub_use_module='use autouse (Carp => qw(carp))'
            ;;
         'encoding')
            perlsub_use_module='use encoding q{utf8}'
            ;;
         'feature')
            perlsub_use_module='use feature q{say}'
            ;;
         'filetest')
            perlsub_use_module='use filetest q{access}'
            ;;
         'if')
            perlsub_use_module='use if 0, q{strict}'
            ;;
         'open')
            perlsub_use_module='use open q{:locale}'
            ;;
         'sort')
            perlsub_use_module='use sort q{stable}'
            ;;
         *)
            perlsub_use_module="use $module"
            ;;
    esac
    export perlsub_use_module
}

perlsubLibraryLoaded() {
    local perlbin=${PERL_BIN:-perl}
    if which $perlbin &>/dev/null ; then
        rlLogDebug "Library perl/subpackage available"
        return 0
    else
        rlLogError "$perlbin not found"
        return 1
    fi
}
