# For docs, see
# http://wiki.basho.com/Configuration-Files.html#app.config
#
# == Parameters
#
# cfg:
#   A configuration hash of erlang to be written to
#   File[/etc/riak/app.config]. It's recommended to browse
#   the 'appconfig.pp' file to see sample values.
#
# source:
#   The source of the app.config file, if you wish to define it
#   explicitly rather than rely on the hash. This parameter
#   is mutually exclusive with 'template'.
#
# template:
#   An ERB template file for app.config, if you wish to define it
#   explicitly rather than rely on the hash. This parameter
#   is mutually exclusive with 'source'.
#
# absent:
#   If true, the configuration file is ensured to be absent from
#   the system.
#
class riak::appconfig(
  $template = "riak/app.config.erb" ,
  $absent = false,
  $search_enabled = false,
  $ring_size = 64,
  $default_bucket_props_n_val = 3,
  $target_n_val = 5,
  $http_url_encoding = 'off',
  $legacy_keylisting = 'false',
  $storage_backend = 'riak_kv_eleveldb_backend'
) {

  require riak::params

  $manage_file = $absent ? {
    true    => 'absent',
    default => 'present',
  }

  $manage_template = $template ? {
    default => template($template),
  }

  $manage_source = $source ? {
    ''      => undef,
    default => $source,
  }

  anchor { 'riak::appconfig::start': }

#  file { [
##      $appcfg[riak_core][platform_log_dir],
#      '/etc/riak'
##      $appcfg[riak_core][platform_lib_dir],
##      $appcfg[riak_core][platform_data_dir],
#    ]:
#    ensure  => directory,
#    mode    => '0755',
#    owner   => 'riak',
#    require => Anchor['riak::appconfig::start'],
#    before  => Anchor['riak::appconfig::end'],
#  }

  file { "/etc/riak/app.config":
    ensure  => $manage_file,
    content => $manage_template,
    source  => $manage_source,
    require => [
      File['/etc/riak'],
#      File["${$appcfg[riak_core][platform_log_dir]}"],
#      File["${$appcfg[riak_core][platform_lib_dir]}"],
#      File["${$appcfg[riak_core][platform_data_dir]}"],
      Anchor['riak::appconfig::start'],
    ],
    before  => Anchor['riak::appconfig::end'],
  }

  anchor { 'riak::appconfig::end': }
}
