#***********************************************************************
#
# Name: pdf_extract_links.pm	
#
# $Revision$
# $URL$
# $Date$
#
# Description:
#
#   This file contains routines that extract links from PDF documents.
#
# Public functions:
#     PDF_Extract_Links
#     PDF_Extract_Links_Debug
#
# Terms and Conditions of Use
# 
# Unless otherwise noted, this computer program source code
# is covered under Crown Copyright, Government of Canada, and is 
# distributed under the MIT License.
# 
# MIT License
# 
# Copyright (c) 2011 Government of Canada
# 
# Permission is hereby granted, free of charge, to any person obtaining a
# copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense, 
# and/or sell copies of the Software, and to permit persons to whom the 
# Software is furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
# OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR 
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR 
# OTHER DEALINGS IN THE SOFTWARE.
# 
#***********************************************************************

package pdf_extract_links;

use strict;
use warnings;
use File::Basename;
use URI::URL;

#***********************************************************************
#
# Export package globals
#
#***********************************************************************
BEGIN {
    use Exporter   ();
    use vars qw($VERSION @ISA @EXPORT);

    @ISA     = qw(Exporter);
    @EXPORT  = qw(PDF_Extract_Links
                  PDF_Extract_Links_Debug);
    $VERSION = "1.0";
}

#***********************************************************************
#
# File Local variable declarations
#
#***********************************************************************

my (@paths, $this_path, $program_dir, $program_name, $paths);
my ($debug) = 0;
my ($pdftohtml_cmnd);

#********************************************************
#
# Name: PDF_Extract_Links_Debug
#
# Parameters: this_debug - debug flag
#
# Description:
#
#   This function sets the package debug flag.
#
#********************************************************
sub PDF_Extract_Links_Debug {
    my ($this_debug) = @_;

    #
    # Copy debug flag to global
    #
    $debug = $this_debug;
}

#***********************************************************************
#
# Name: PDF_Extract_Links
#
# Parameters: url - URL of document to extract links from
#             base - base for converting relative to absolute url
#             language - language of URL
#             content - content of PDF document to extract links from
#
# Description:
#
#   This function extracts links from the supplied content and
# returns the details in the supplied arrays.
#
#***********************************************************************
sub PDF_Extract_Links {
    my ( $url, $base, $language, $content ) = @_;

    my ($pdf_file_name, $html_file_name, $link, $href, $rc);
    my (@link_objects, $abs_url);
    my (@pdf_link_objects) = ();

    #
    # Did we get any content ?
    #
    print "PDF_Extract_Links: URL $url\n" if $debug;
    if ( length($content) > 0 ) {

        #
        # Create temporary file for PDF content.
        #
        $pdf_file_name = "pdf_text$$.pdf";
        $html_file_name = "pdf_text$$.html";
        unlink($pdf_file_name, $html_file_name);
        print "Create temporary PDF file $pdf_file_name\n" if $debug;
        open(PDF, ">$pdf_file_name") ||
            die "PDF_Extract_Links: Failed to open $pdf_file_name for writing\n";
        binmode PDF;
        print PDF $content;
        close(PDF);

        #
        # Convert the PDF file to an HTML file
        #
        $rc = `$pdftohtml_cmnd -noframes -i $pdf_file_name 2>\&1`;
        unlink($pdf_file_name);

        #
        # Open the HTML file
        #
        if ( ! open(HTML, "$html_file_name") ) {
            #
            # Failed to open file, probably the pdf to html conversion failed.
            # Ignore this error and assume there are no links in the document.
            #
            print "PDF_Extract_Links: Failed to open $html_file_name for reading\n" if $debug;
            return(@pdf_link_objects);
        }

        #
        # Read the HTML file content
        #
        $content = "";
        while ( <HTML> ) {
            $content .= $_ . "\n";
        }
        close(HTML);

        #
        # Cleanup temporary files
        #
        unlink($html_file_name);

        #
        # Extract links from the HTML content
        #
        @link_objects = Extract_Links($url, $base, $language, "text/html",
                                      $content);

        #
        # Eliminate links to sections of the document (e.g. from
        # table of content to actual section).
        #
        print "Eliminate links to sections within the document\n" if $debug;
        foreach $link (@link_objects) {
            #
            # If the link href is something other than the
            # file name, it is a valid link
            #
            $href = $link->href;
            if ( ($href =~ /^$html_file_name.*/) || ($href =~ /^\s*$/) ) {
                #
                # Ignore this link.
                #
                print "Ignore link at Line/column: " . $link->line_no .
                      ":" .  $link->column_no . 
                      " href = " . $link->href .
                      " anchor = " . $link->anchor . "\n" if $debug;
            }
            else {
                #
                # Erase some link details.  Items such as line number
                # are for the generated HTML file, not the original
                # PDF file.
                #
                $link->line_no(-1);
                $link->column_no(-1);
                $link->source_line("");

                #
                # Copy link details
                #
                push (@pdf_link_objects, $link);
            }
        }

        #
        # Dump list of extracted links
        #
        if ( $debug ) {
            print "PDF Links extracted from $url\n";
            foreach $link (@pdf_link_objects) {
                print "Link at Line/column: " . $link->line_no . ":" . $link->column_no .
                      " type = " . $link->link_type .
                      " lang = " . $link->lang . "\n";
                print " href = " . $link->href .
                      " anchor = " . $link->anchor . "\n";
            }
        }
    }
    else {
        print "PDF_Extract_Links: no content in document\n" if $debug;
    }

    #
    # Return list of links
    #
    return(@pdf_link_objects);
}

#***********************************************************************
#
# Name: Import_Packages
#
# Parameters: none
#
# Description:
#
#   This function imports any required packages that cannot
# be handled via use statements.
#
#***********************************************************************
sub Import_Packages {

    my ($package);
    my (@package_list) = ("extract_links");

    #
    # Import packages, we don't use a 'use' statement as these packages
    # may not be in the INC path.
    #
    foreach $package (@package_list) {
        #
        # Import the package routines.
        #
        if ( ! defined($INC{$package}) ) {
            require "$package.pm";
        }
        $package->import();
    }

}

#***********************************************************************
#
# Mainline
#
#***********************************************************************

#
# Get our program directory, where we find supporting files
#
$program_dir  = dirname($0);
$program_name = basename($0);

#
# If directory is '.', search the PATH to see where we were found
#
if ( $program_dir eq "." ) {
    $paths = $ENV{"PATH"};
    @paths = split( /:/, $paths );

    #
    # Loop through path until we find ourselves
    #
    foreach $this_path (@paths) {
        if ( -x "$this_path/$program_name" ) {
            $program_dir = $this_path;
            last;
        }
    }
}

#
# Add to path for shared libraries (Solaris only)
#
if ( defined $ENV{LD_LIBRARY_PATH} ) {
    $ENV{LD_LIBRARY_PATH} .= ":/usr/local/lib:/opt/sfw/lib";
}
else {
    $ENV{LD_LIBRARY_PATH} = "/usr/local/lib:/opt/sfw/lib";
}

#
# Generate path supporting commands
# variable
#
if ( $^O =~ /MSWin32/ ) {
    #
    # Windows.
    #
    $pdftohtml_cmnd = "pdftohtml";
} else {
    #
    # Not Windows.
    #
    $pdftohtml_cmnd = "$program_dir/pdftohtml";
}

#
# Import required packages
#
Import_Packages;

#
# Return true to indicate we loaded successfully
#
return 1;

