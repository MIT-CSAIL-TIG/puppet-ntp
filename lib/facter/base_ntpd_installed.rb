# base_ntpd_installed.rb
Facter.add(:base_ntpd_installed) do
  confine :osfamily => 'FreeBSD'
  setcode do
    File.executable?('/usr/sbin/ntpd') and File.file?('/etc/rc.d/ntpd')
  end
end
