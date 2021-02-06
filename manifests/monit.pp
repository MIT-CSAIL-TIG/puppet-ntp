#
# Tell monit, if we are using it, to restart ntpd if it dies for some reason.
# (We should really have a way to figure out if the monit module is available.)
#
define ntp::monit ($managed_service = $name, $pidfile) {
  # The title of this resource must be the name of the service (as known
  # to the rc scripts).
  @monit::monitor {$managed_service:
    pidfile => $pidfile,
    tag => 'default',
  }
}
