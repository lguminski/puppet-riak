# Class: riak
#
# This module manages Riak, the dynamo-based NoSQL database.
#
# == Parameters
#
# version:
#   Version of package to fetch.
#
# package:
#   Name of package as known by OS.
#
# package_hash:
#   A URL of a hash-file or sha2-string in hexdigest
#
# source:
#   Sets the content of source parameter for main configuration file
#   If defined, riak's app.config file will have the param: source => $source.
#   Mutually exclusive with $template.
#
# template:
#   Sets the content of the content parameter for the main configuration file
#
# architecture:
#   What architecture to fetch/run on
#
# == Requires
#
# * stdlib (module)
# * hiera-puppet (module)
# * hiera (package in 2.7.x, but included inside Puppet 3.0)
#
# == Usage
#
# === Default usage:
#   This gives you all the defaults:
#
# class { 'riak': }
#
# === Overriding configuration
#
#   In this example, we're adding HTTPS configuration
#   with a certificate file / public key and a private
#   key, both placed in the /etc/riak folder.
#
#   When you add items to the 'cfg' parameter, they will override the
#   already defined defaults with those keys defined. The hash is not
#   hard-coded, so you don't need to change the manifest when new config
#   options are made available.
#
#   You can probably benefit from using hiera's hierarchical features
#   in this case, by defining defaults in a yaml file for all nodes
#   and only then configuring specifics for each node.
#
#  class { 'riak':
#    cfg => {
#      riak_core => {
#        https => {
#          "__string_${$::ipaddress}" => 8443
#        },
#        ssl => {
#          certfile => "${etc_dir}/cert.pem",
#          keyfile  => "${etc_dir}/key.pem",
#        }
#      }
#    }
#  }
#
# == Author
#   Henrik Feldt, github.com/haf/puppet-riak.
#
class riak (
  $version             = $riak::params::version,
  $package             = $riak::params::package,
  $download            = $riak::params::download,
  $use_repos           = $riak::params::use_repos,
  $download_hash       = $riak::params::download_hash,
  $source              = '',
  $vmargs_template     = "riak/vm.args.erb",
  $template            = "riak/app.config.erb",
  $architecture        = $riak::params::architecture,
  $log_dir             = $riak::params::log_dir,
  $erl_log_dir         = $riak::params::erl_log_dir,
  $etc_dir             = $riak::params::etc_dir,
  $data_dir            = $riak::params::data_dir,
  $service_autorestart = $riak::params::service_autorestart,
  $disable             = false,
  $disableboot         = false,
  $absent              = false,
  $riak_node           = 'test-akka-001.flatns.net'
) inherits riak::params {

  include stdlib

  $pkgfile = "/tmp/${$package}-${$version}.${$riak::params::package_type}"

  File {
    owner => 'root',
    group => 'root',
    mode  => '0644',
  }

  $manage_package = $absent ? {
    true    => 'absent',
    default => 'installed',
  }

  $manage_service_ensure = $disable ? {
    true    => 'stopped',
    default => $absent ? {
      true    => 'stopped',
      default => 'running',
    },
  }

  $manage_service_enable = $disableboot ? {
    true    => false,
    default => $disable ? {
      true    => false,
      default => $absent ? {
        true    => false,
        default => true,
      },
    },
  }

  $manage_file = $absent ? {
    true    => 'absent',
    default => 'present',
  }

  $manage_service_autorestart = $service_autorestart ? {
    /true/  => 'Service[riak]',
    default => undef,
  }

  anchor { 'riak::start': }

  package { $riak::params::deps:
    ensure  => $manage_package,
    require => Anchor['riak::start'],
    before  => Anchor['riak::end'],
  }

  if $use_repos == true {
    package { $package:
      ensure  => $manage_package,
      require => [
        Class['riak::config'],
        Package[$riak::params::deps],
        Anchor['riak::start'],
      ],
      before  => Anchor['riak::end'],
    }
  } else {
    #file {  $pkgfile:
    #  ensure  => present,
    #  source  => $download,
    #  require => Anchor['riak::start'],
    #  before  => Anchor['riak::end'],
    #}
    package { 'riak':
      ensure   => $manage_package,
      source   => $pkgfile,
      provider => $riak::params::package_provider,
      require  => [
    #    File[$pkgfile],
        Package[$riak::params::deps],
        Anchor['riak::start'],
      ],
      before   => Anchor['riak::end'],
    }
  }

    package { 'avahi-tools':
      ensure   => $manage_package,
      require  => [
    #    File[$pkgfile],
        Anchor['riak::start'],
      ],
      before   => Anchor['riak::end'],
    }

  file { $etc_dir:
    ensure  => directory,
    mode    => '0755',
    require => Anchor['riak::start'],
    before  => Anchor['riak::end'],
  }

  file { "/tmp/register.sh":
    ensure  => $manage_file,
    mode    => '0755',
    content => template('riak/register.sh.erb'),
    require => Anchor['riak::start'],
    before  => Anchor['riak::end']
  }

 exec { 'register_riak':
   command => '/tmp/register.sh',
   logoutput => "on_failure",
   require => [ File['/tmp/register.sh'] ],
 }


  class { 'riak::appconfig':
    absent   => $absent,
    template => $template,
    require  => [
      File[$etc_dir],
      Anchor['riak::start'],
    ],
    notify   => $manage_service_autorestart,
    before   => Anchor['riak::end'],
  }

  class { 'riak::config':
    absent       => $absent,
    manage_repos => $use_repos,
    require      => Anchor['riak::start'],
    before       => Anchor['riak::end'],
  }

  class { 'riak::vmargs':
    absent  => $absent,
    template => $vmargs_template,
    require => [
      File[$etc_dir],
      Anchor['riak::start'],
    ],
    before  => Anchor['riak::end'],
    notify  => $manage_service_autorestart,
  }

  group { 'riak':
    ensure => present,
    require => Anchor['riak::start'],
    before  => Anchor['riak::end'],
  }

  user { 'riak':
    ensure  => ['present'],
    gid     => 'riak',
    home    => $data_dir,
    require => [
      Group['riak'],
      Anchor['riak::start'],
    ],
    before  => Anchor['riak::end'],
  }

  service { 'riak':
    ensure  => $manage_service_ensure,
    enable  => $manage_service_enable,
    require => [
      Class['riak::appconfig'],
      Class['riak::vmargs'],
      Class['riak::config'],
      User['riak'],
      Package['riak'],
      Anchor['riak::start'],
    ],
    before  => Anchor['riak::end'],
  }

  anchor { 'riak::end': }
}
