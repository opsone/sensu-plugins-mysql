#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mysql2'
require 'sensu-plugin/check/cli'

class CheckMysql < Sensu::Plugin::Check::CLI
  option :user,
         description: 'MySQL User',
         short: '-u USER',
         long: '--user USER',
         default: 'root'

  option :password,
         description: 'MySQL Password',
         short: '-p PASS',
         long: '--password PASS'

  option :hostname,
         description: 'Hostname to login to',
         short: '-h HOST',
         long: '--hostname HOST',
         default: '127.0.0.1'

  option :database,
         description: 'Database schema to connect to',
         short: '-d DATABASE',
         long: '--database DATABASE',
         default: 'mysql'

  option :port,
         description: 'Port to connect to',
         short: '-P PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 3306

  option :socket,
         description: 'Socket to use',
         short: '-S SOCKET',
         long: '--socket SOCKET'

  def run
    client = Mysql2::Client.new(host: config[:hostname], username: config[:user], password: config[:password], port: config[:port], database: config[:database], socket: config[:socket])
    info = client.server_info
    ok "Server version: #{info[:version]}"
  rescue Mysql2::Error => e
    critical "MySQL check failed: #{e.error}"
  ensure
    client&.close
  end
end
