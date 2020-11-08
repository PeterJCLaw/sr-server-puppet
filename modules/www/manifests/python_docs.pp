# Create a clone of python's docs on our website.

class www::python_docs ( $web_root_dir, $version ) {

  # Install python docs unless they're already there.
  # We use the name of the archive we're passed as part of the already-there
  # key so that they'll be updated if it changes.

  $archive_name = "python-${version}-docs-html"
  $target_root = '/srv/python-docs/'
  $target_dir = "${$target_root}${archive_name}"

  # wget is generally nicer than curl for downloading things.
  package {'wget':
    ensure => present,
  }

  # bzip2 is needed to unzip source
  package {'bzip2':
    ensure => present,
  }

  file { $target_root:
    ensure => 'directory',
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2755',
  }

  exec { 'extract-python-docs':
    command =>
       "rm -rf ${target_dir} ;\
          wget -O - https://www.python.org/ftp/python/doc/${version}/${archive_name}.tar.bz2 | tar -xj -C ${target_root} ",
    provider => 'shell',
    creates => $target_dir,
    require => [Package['wget'],File[$target_root],Package['bzip2']],
  }

  file { "${web_root_dir}/docs":
    ensure => 'directory',
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2755',
  }

  file { "${web_root_dir}/docs/python":
    ensure => 'link',
    target => $target_dir,
    owner => 'wwwcontent',
    group => 'apache',
    mode => '2755',
    require => File["${web_root_dir}/docs"],
  }
}
