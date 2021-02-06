class ntp::munin {
    @munin::plugin {['ntp_offset', 'ntp_kernel_err', 'ntp_kernel_pll_freq',
		   'ntp_kernel_pll_off']:
    config => 'env.PATH /usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin',
    tag => 'standard',
  }
}
