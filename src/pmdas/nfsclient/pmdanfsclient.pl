#
# Copyright (c) 2011 SGI.
# All rights reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the
# Free Software Foundation; either version 2 of the License, or (at your
# option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#

use strict;
use warnings;
use PCP::PMDA;

# The instance domain is 0 for all nfs client stats
our  $nfsclient_indom = 0;

# The instances hash is converted to an array and passed to add_indom (and
# replace_indom) in the second arg.  It is keyed on the instance number which
# starts at 1 and is incremented for each nfs mount in the mountstats file.
# The value is the server export string, e.g. 'hostname:/export', which happens
# to be the key of the stats hash.
our %instances = ();

# The stats hash is keyed on the 'device' string (the export string), e.g.
# 'hostname:/export'.  The value is a hash ref, and that hash contains all of
# the stats data keyed on pmid_name
our %h = ();

#
# Parse /proc/self/mountstats and store the stats, taking one pass through
# the file.
#
sub nfsclient_parse_proc_mountstats {
	# mountstats output has a section for each mounted filesystems on the
	# system.  Each section starts with a line like:  'device X mounted on
	# Y with fstype Z'.  Some filesystems (like nfs) print additional
	# output that we need to capture.
	open STATS, "< /proc/self/mountstats"
		or die "Can't open /proc/self/mountstats: $!\n";

	my $i = 0;	# instance number
	my $export;
	while (<STATS>) {
		my $line = $_;

		# does this line represent a mount?
		if ($line =~ /^device (\S*) mounted on (\S*) with fstype.*/) {
			$export = $1;
			my $mtpt = $2;

			# is it an nfs mount?
			if ($line =~ /.*nfs statvers=1\.0$/) {
				$instances{$i++} = $export; # a new instance
				$h{$export} = {}; # {} is an anonymous hash ref
				$h{$export}->{'nfsclient.export'} = $export;
				$h{$export}->{'nfsclient.mtpt'} = $mtpt; 
			} else {
				# the following lines aren't nfs so undef
				# $export so that they are ignored below
				undef $export;
				next;
			}
		}

		# skip lines that do not belong to nfs mounts
		if (not defined $export) {
			next;
		}

		# TODO parse nfs stats and put them in $h
		# events
		if ($line =~ /^\tevents:\t(.*)$/) {
			($h{$export}->{'nfsclient.events.inoderevalidate'},
			 $h{$export}->{'nfsclient.events.dentryrevalidate'},
			 $h{$export}->{'nfsclient.events.datainvalidate'},
			 $h{$export}->{'nfsclient.events.attrinvalidate'},
			 $h{$export}->{'nfsclient.events.vfsopen'},
			 $h{$export}->{'nfsclient.events.vfslookup'},
			 $h{$export}->{'nfsclient.events.vfsaccess'},
			 $h{$export}->{'nfsclient.events.vfsupdatepage'},
			 $h{$export}->{'nfsclient.events.vfsreadpage'},
			 $h{$export}->{'nfsclient.events.vfsreadpages'},
			 $h{$export}->{'nfsclient.events.vfswritepage'},
			 $h{$export}->{'nfsclient.events.vfswritepages'},
			 $h{$export}->{'nfsclient.events.vfsgetdents'},
			 $h{$export}->{'nfsclient.events.vfssetattr'},
			 $h{$export}->{'nfsclient.events.vfsflush'},
			 $h{$export}->{'nfsclient.events.vfsfsync'},
			 $h{$export}->{'nfsclient.events.vfslock'},
			 $h{$export}->{'nfsclient.events.vfsrelease'},
			 $h{$export}->{'nfsclient.events.congestionwait'},
			 $h{$export}->{'nfsclient.events.setattrtrunc'},
			 $h{$export}->{'nfsclient.events.extendwrite'},
			 $h{$export}->{'nfsclient.events.sillyrename'},
			 $h{$export}->{'nfsclient.events.shortread'},
			 $h{$export}->{'nfsclient.events.shortwrite'},
			 $h{$export}->{'nfsclient.events.delay'}) =
				split(/ /, $1);
		}
	}

	close STATS;
}

#
# fetch is called once by pcp for each refresh and then the fetch callback is
# called to query each statistic individually
#
sub nfsclient_fetch {
	nfsclient_parse_proc_mountstats();

	our $pmda->replace_indom($nfsclient_indom, [%instances]);
}

#
# the fetch callback returns is passed the cluster and item number (which
# identifies each statistic and is passed to pcp in arg 1 of add_metric) as
# well as the instance id.  Based on this, look up the export name and
# pmid_name, lookup the stat data in the hashes and return it in arg0 of an
# array.
#
sub nfsclient_fetch_callback {
	my ($cluster, $item, $inst) = @_; 

	my $export = $instances{$inst};
	my $pmid_name = pmda_pmid_name($cluster, $item)
		or die "Unknown metric name: cluster $cluster item $item\n";

	return ($h{$export}->{$pmid_name}, 1); # 1 indicates the stat is valid
}

# the PCP::PMDA->new line is parsed by the check_domain rule of the PMDA build
# process, so there are special requirements:  no comments, the domain has to
# be a bare number.
#
# domain 111 was chosen since it doesn't exist in ../pmns/stdpmid
our $pmda = PCP::PMDA->new('nfsclient', 111);

# metrics go here, with full descriptions

# general - cluster 0
$pmda->add_metric(pmda_pmid(0,1), PM_TYPE_STRING, $nfsclient_indom,
		PM_SEM_INSTANT, pmda_units(0,0,0,0,0,0),
		'nfsclient.export',
		'Export',
		'');
$pmda->add_metric(pmda_pmid(0,2), PM_TYPE_STRING, $nfsclient_indom,
		PM_SEM_INSTANT, pmda_units(0,0,0,0,0,0),
		'nfsclient.mtpt',
		'Mount Point',
		'');

# TODO opts - cluster 1
# TODO age - cluster 2
# TODO caps - cluster 3
# TODO sec - cluster 4

# events - cluster 5
$pmda->add_metric(pmda_pmid(5,1), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.inoderevalidate',
		  'NFSIOS_INODEREVALIDATE',
'incremented in __nfs_revalidate_inode whenever an inode is revalidated');

$pmda->add_metric(pmda_pmid(5,2), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.dentryrevalidate',
		  'NFSIOS_DENTRYREVALIDATE',
'incremented in nfs_lookup_revalidate whenever a dentry is revalidated');

$pmda->add_metric(pmda_pmid(5,3), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.datainvalidate',
		  'NFSIOS_DATAINVALIDATE',
'incremented in nfs_invalidate_mapping_nolock when data cache for an inode ' .
'is invalidated');

$pmda->add_metric(pmda_pmid(5,4), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.attrinvalidate',
		  'NFSIOS_ATTRINVALIDATE',
'incremented in nfs_zap_caches_locked and nfs_update_inode when an the ' .
'attribute cache for an inode has been invalidated');

$pmda->add_metric(pmda_pmid(5,5), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsopen',
		  'NFSIOS_VFSOPEN',
'incremented in nfs_file_open and nfs_opendir whenever a file or directory ' .
'is opened');

$pmda->add_metric(pmda_pmid(5,6), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfslookup',
		  'NFSIOS_VFSLOOKUP',
'incremented in nfs_lookup on every lookup');

$pmda->add_metric(pmda_pmid(5,7), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsaccess',
		  '', '');

$pmda->add_metric(pmda_pmid(5,8), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsupdatepage',
		  '', '');

$pmda->add_metric(pmda_pmid(5,9), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsreadpage',
		  '', '');

$pmda->add_metric(pmda_pmid(5,10), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsreadpages',
		  '', '');

$pmda->add_metric(pmda_pmid(5,11), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfswritepage',
		  '', '');

$pmda->add_metric(pmda_pmid(5,12), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfswritepages',
		  '', '');

$pmda->add_metric(pmda_pmid(5,13), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsgetdents',
		  '', '');

$pmda->add_metric(pmda_pmid(5,14), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfssetattr',
		  '', '');

$pmda->add_metric(pmda_pmid(5,15), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsflush',
		  '', '');

$pmda->add_metric(pmda_pmid(5,16), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsfsync',
		  '', '');

$pmda->add_metric(pmda_pmid(5,17), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfslock',
		  '', '');

$pmda->add_metric(pmda_pmid(5,18), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.vfsrelease',
		  '', '');

$pmda->add_metric(pmda_pmid(5,19), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.congestionwait',
		  '', '');

$pmda->add_metric(pmda_pmid(5,20), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.setattrtrunc',
		  '', '');

$pmda->add_metric(pmda_pmid(5,21), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.extendwrite',
		  '', '');

$pmda->add_metric(pmda_pmid(5,22), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.sillyrename',
		  '', '');

$pmda->add_metric(pmda_pmid(5,23), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.shortread',
		  '', '');

$pmda->add_metric(pmda_pmid(5,24), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.shortwrite',
		  '', '');

$pmda->add_metric(pmda_pmid(5,25), PM_TYPE_U32, $nfsclient_indom,
		  PM_SEM_COUNTER, pmda_units(0,0,1,0,0,PM_COUNT_ONE),
		  'nfsclient.events.delay',
		  '', '');

&nfsclient_parse_proc_mountstats;
$pmda->add_indom($nfsclient_indom, [%instances], 'NFS mounts', '');

$pmda->set_fetch(\&nfsclient_fetch);
$pmda->set_fetch_callback(\&nfsclient_fetch_callback);

$pmda->run;
