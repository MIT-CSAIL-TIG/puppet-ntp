class ntp::defaults {
  # This assumes that we always want to use the packaged version of
  # NTP on FreeBSD, which isn't necessarily the case, but we make
  # it simpler by not building the base-system NTP so there is no
  # confusion.  Other sites may not want to do it this way.
  $managed_package = $::osfamily ? {
	'FreeBSD' => 'ntp',
	'Debian'  => 'ntp',
	default   => undef
  }

  # Debian-based systems use a different name for the init script.
  # This must be defined to a useful value -- undef is not an option.
  $managed_service = $::osfamily ? {
	'Debian'  => 'ntp',
	default   => 'ntpd',
  }

  # Most machines are clients, not servers.
  $server = 0 != 0

  # Different operating systems put the drift file in different places.
  $driftfile          = $::osfamily ? {
	'FreeBSD' => '/var/db/ntpd.drift',
	'Debian'  => '/var/lib/ntp/ntp.drift',
	default   => '/etc/ntp.drift',
  }

  #
  # Only used if ntp_servers is empty or undefined -- ensures that
  # ntpd does something useful even if {un,mis}configured.
  #
  $pool_servers       = [ '0.pool.ntp.org',
			       '1.pool.ntp.org',
			       '2.pool.ntp.org',
			       '3.pool.ntp.org', ]

  $pool_server_options= 'iburst'

  # To be defined in hiera YAML files if used:
  $servers = []
  $server_options = {}
  $peers = []
  $refclocks = []
  $keys = {}

  # Most sites probably won't install a leapseconds file.  Note that
  # the configuration for leapseconds depends on which version of
  # ntpd you are running; it only makes sense to enable this on machines
  # that have ntpd 4.2.6 or later.  This file needs to be updated
  # soon after the announcement (IERS Bulletin C) of a new leap second
  # insertion or deletion.  This file is obtained from
  #   ftp://tycho.usno.navy.mil/pub/ntp/leap-seconds.${timestamp}
  # where ${timestamp} is the number of NTP seconds since 1900.0.
  $leapseconds = false
  $leapseconds_file = 'puppet:///modules/ntp/leap-seconds.3536142400'
}
