# Install nginx
#
# layout for linux port
# all of the keywords for each os are figured out at the top
# sections that only make sense for one OS to run are fenced with if $::osfamilytype statements
# as much code can be shared, is, in the spirit of maintainability and predictability
class nginx(
  $ensure = present,
) {
  include nginx::config
  include homebrew

  if $::osfamily == 'Darwin' {
    $nginx_package_ensure   = '1.4.4-boxen1'
    $nginx_package_name     = 'boxen/brews/nginx'
    $nginx_package_provider = homebrew
    $nginx_service_name     = 'dev.nginx'
  }
  elsif $::osfamily == 'Debian' {
    $nginx_package_ensure   = latest
    $nginx_package_name     = 'nginx-full'
    $nginx_package_provider = apt
    $nginx_service_name     = 'nginx'
  }
  else {
    fail("Unsupported OS for dnsmasq module")
  }

  case $ensure {
    present: {
      if $::osfamily == 'Darwin' {
        # Install our custom plist for nginx. This is one of the very few
        # pieces of setup that takes over priv. ports (80 in this case).

        file { '/Library/LaunchDaemons/dev.nginx.plist':
          content => template('nginx/dev.nginx.plist.erb'),
          group   => $::rootgroup,
          notify  => Service[$nginx_service_name],
          owner   => $::rootuser
        }

        # Set up all the files and directories nginx expects. We go
        # nonstandard on this mofo to make things as clearly accessible as
        # possible under $BOXEN_HOME.

        file { [
          $nginx::config::configdir,
          $nginx::config::datadir,
          $nginx::config::logdir,
          $nginx::config::sitesdir
        ]:
          ensure => directory
        }

        file { $nginx::config::configfile:
          content => template('nginx/config/nginx/nginx.conf.erb'),
          notify  => Service[$nginx_service_name]
        }

        file { "${nginx::config::configdir}/mime.types":
          notify  => Service[$nginx_service_name],
          source  => 'puppet:///modules/nginx/config/nginx/mime.types'
        }

        # Set up a very friendly little default one-page site for when
        # people hit http://localhost.

        file { "${nginx::config::configdir}/public":
          ensure  => directory,
          recurse => true,
          source  => 'puppet:///modules/nginx/config/nginx/public'
        }

        homebrew::formula { 'nginx':
          before => Package['boxen/brews/nginx'],
        }

        # Remove Homebrew's nginx config to avoid confusion.

        file { "${boxen::config::home}/homebrew/etc/nginx":
          ensure  => absent,
          force   => true,
          recurse => true,
          require => Package['boxen/brews/nginx']
        }
      }

      package {
        $nginx_package_name:
          ensure => $nginx_package_ensure,
          provider => $nginx_package_provider,
          notify => Service[$nginx_service_name],
      }

      service { $nginx_service_name:
        ensure  => running,
        require => Package[$nginx_package_name]
      }
    }

    absent: {
      service { $nginx_service_name:
        ensure  => stopped,
      }

      if $::osfamily == 'Darwin' {
        file { '/Library/LaunchDaemons/dev.nginx.plist':
          ensure => absent
        }

        file { [
          $nginx::config::configdir,
          $nginx::config::datadir,
          $nginx::config::logdir,
          $nginx::config::sitesdir
        ]:
          ensure => absent
        }
      }

      package { $nginx_service_name:
          ensure => absent,
        }
    }

    default: {
      fail('Nginx#ensure must be present or absent!')
    }
  }
}
