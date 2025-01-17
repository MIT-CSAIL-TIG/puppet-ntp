# Class: ntp
#
# Actions:
#
# Requires: 
#
class ntp (
  $config_file,
  $server,
  $driftfile,
  $pool_servers,
  $pool_server_options,
  $managed_package,
  $managed_service,
  $leapseconds,
  $leapseconds_file,
  $leapseconds_source,
  $pidfile,
  $auto_leapseconds,
  $auto_leapseconds_file = undef,
  $servers = [],
  $server_options = {},
  $peers = [],
  $refclocks = undef,
  $keys = {},
  $extras = undef,
  $management_stations = hiera_array('management_stations', []),
  ) {

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
  } elsif $::osfamily == 'FreeBSD' {
    file_line { 'ntpd_program':
      ensure    => absent,
      path      => '/etc/rc.conf',
      match     => '^ntpd_program=',
      match_for_absence => true,
      before    => [ Service['ntp'] ],
    }
  }

  service { 'ntp':
    ensure    => running,
    enable    => true,
    name      => $managed_service,
  }
  if $managed_package {
    Package['ntp'] -> Service['ntp']
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
	subscribe => [ File[$config_file] ],
    }
  }

  # Only do this on FreeBSD.  Debian will restart ntpd automatically
  # on package updates, so making this global will only result in an
  # unnecessary restart, which increases the chance that Nagios will
  # see it in an unsynchronized state and raise the alarm.
  if $::osfamily == 'FreeBSD' and $managed_package {
    Package['ntp'] { notify => Service['ntp'], }
  }

  file {$config_file:
    owner  => 0,
    group  => 0,
    mode   => '0644',
  }
  if $managed_package {
    File[$config_file] { require => Package['ntp'], }
  }
  if !$server {
    File[$config_file] { notify => Service['ntp'], }
  }

  if $server {
    File[$config_file] {
      content => template('ntp/ntp.conf.header.erb',
	'ntp/ntp.conf.server_opt.erb', 'ntp/ntp.conf.servers.erb',
	'ntp/ntp.conf.extras.erb'),
    }
  } else {
    File[$config_file] {
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
      content => template('ntp/ntp.keys.erb'),
    }
    if $managed_package {
      Package['ntp'] -> File['/etc/ntp.keys']
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
      require => File[$config_file],
    }
  } else {
    file {'/etc/ntp.leapseconds':
      ensure  => absent,
    }
  }

  include ntp::munin
}
