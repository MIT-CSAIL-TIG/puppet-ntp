# Class: ntp
#
# Actions:
#
# Requires: 
#
# Notes: No reasonable client will actually try to set any of these,
# except maybe the first.  This kluge is only used to tell Puppet to
# look up the answers in Hiera "the new way".  Unfortunately, this
# forces the rest of the implementation to be spaghetti rather than a
# sensible class hierarchy.  Prepare to be disgusted.
#
class ntp (
	$server = $ntp::defaults::server,
	$driftfile = $ntp::defaults::driftfile,
	$servers = $ntp::defaults::servers,
	$server_options = $ntp::defaults::server_options,
	$pool_servers = $ntp::defaults::pool_servers,
	$pool_server_options = $ntp::defaults::pool_server_options,
	$peers = $ntp::defaults::peers,
	$refclocks = undef,
	$keys = $ntp::defaults::keys,
	$extras = undef,
	$management_stations = hiera_array('management_stations', []),
	$managed_package = $ntp::defaults::managed_package,
	$managed_service = $ntp::defaults::managed_service,
	$leapseconds = $ntp::defaults::leapseconds,
	$leapseconds_file = $ntp::defaults::leapseconds_file,
	) inherits ntp::defaults {

  if ($managed_package) {
    package { 'ntp':
      ensure => present,
      name   => $managed_package,
    }
  }
  
  # Becase we're using the ports version of ntpd, we have to tell the
  # startup script where to find it, and there's no ntpdate any more.
  if $::osfamily == 'FreeBSD' and $managed_package {
    file_line { 'ntpd_program':
      path	=> '/etc/rc.conf',
      line	=> "ntpd_program=\"/usr/local/sbin/ntpd\"",
      match	=> '^ntpd_program=',
      before	=> [ Service['ntp'] ],
      require	=> [ Package['ntp'] ],
    }

    file_line { 'ntpd_sync_on_start':
      path	=> '/etc/rc.conf',
      line	=> 'ntpd_sync_on_start="YES"',
      match	=> '^ntpd_sync_on_start=',
      before	=> [ Service['ntp'] ],
      require	=> [ Package['ntp'] ],
    }

    service { 'ntpdate':
      enable	=> false,
    }
  }

  service { 'ntp':
    ensure    => running,
    enable    => true,
    name      => $managed_service,
    require   => Package['ntp'],
  }

  # OK to restart ntpd on a client, not so on a server.
  # We should have an Exec here that subscribes to ntp.conf changes
  # and uses the new-fangled "config-from-file" command in ntpq.
  # That requires a lot of mechanism that doesn't exist yet.
  if $server {
    Service['ntp'] {
	hasrestart => false,
    }
  } else {
    Service['ntp'] {
	hasrestart => true,
	subscribe => [ File['/etc/ntp.conf'] ],
    }
  }

  # Only do this on FreeBSD.  Debian will restart ntpd automatically
  # on package updates, so making this global will only result in an
  # unnecessary restart, which increases the chance that Nagios will
  # see it in an unsynchronized state and raise the alarm.
  if $::osfamily == 'FreeBSD' and $managed_package {
    Package['ntp'] { notify => Service['ntp'], }
  }

  file {'/etc/ntp.conf':
    owner  => 0,
    group  => 0,
    mode   => '0644',
  }
  if $managed_package {
    File['/etc/ntp.conf'] { require => Package['ntp'], }
  }
  if !$server {
    File['/etc/ntp.conf'] { notify => Service['ntp'], }
  }

  if $server {
    File['/etc/ntp.conf'] {
      content => template('ntp/ntp.conf.header.erb',
	'ntp/ntp.conf.server_opt.erb', 'ntp/ntp.conf.servers.erb',
	'ntp/ntp.conf.extras.erb'),
    }
  } else {
    File['/etc/ntp.conf'] {
      content => template('ntp/ntp.conf.header.erb',
	'ntp/ntp.conf.client_opt.erb', 'ntp/ntp.conf.servers.erb',
	'ntp/ntp.conf.extras.erb'),
    }
  }

  # Only servers get ntp.keys files for now.  Clients can be
  # managed by editing the config file and restarting the server.
  if $server and $keys {
    file {'/etc/ntp.keys':
      ensure  => file,
      owner   => 0,
      group   => 0,
      mode    => '0600',
      require => Package['ntp'],
      content => template('ntp/ntp.keys.erb'),
    }
  }

  # If we want to install the leapseconds file, do so.
  if $leapseconds {
    file {'/etc/ntp.leapseconds':
      ensure  => file,
      owner   => 0,
      group   => 0,
      mode    => '0444',
      replace => true,
      source  => $leapseconds_file,
      require => File['/etc/ntp.conf'],
    }
  } else {
    file {'/etc/ntp.leapseconds':
      ensure  => absent,
    }
  }

  @munin::plugin {['ntp_offset', 'ntp_kernel_err', 'ntp_kernel_pll_freq',
		   'ntp_kernel_pll_off']:
    config => 'env.PATH /usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    tag => 'standard',
  }

  # The title of this resource must be the name of the service (as known
  # to the rc scripts).
  @monit::monitor {$managed_service:
    pidfile => '/var/run/ntpd.pid',
    tag => 'default',
  }
}
