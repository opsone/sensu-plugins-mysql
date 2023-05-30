#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mysql2'
require 'sensu-plugin/check/cli'

class CheckMysqlConnections < Sensu::Plugin::Check::CLI
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

  option :maxwarn,
         description: "Number of connections upon which we'll issue a warning",
         short: '-w NUMBER',
         long: '--warnnum NUMBER',
         proc: proc(&:to_i),
         default: 100

  option :maxcrit,
         description: "Number of connections upon which we'll issue an alert",
         short: '-c NUMBER',
         long: '--critnum NUMBER',
         proc: proc(&:to_i),
         default: 128

  option :usepc,
         description: 'Use percentage of defined max connections instead of absolute number',
         short: '-a NUMBER',
         long: '--percentage',
         default: false

  def run
    client = Mysql2::Client.new(host: config[:hostname], username: config[:user], password: config[:password], port: config[:port], database: config[:database], socket: config[:socket])

    max_con = client.query("SHOW VARIABLES LIKE 'max_connections'").first['Value'].to_i
    used_con = client.query("SHOW GLOBAL STATUS LIKE 'Threads_connected'").first['Value'].to_i
    used = config[:usepc] ? used_con.fdiv(max_con) * 100 : used_con

    critical "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used >= config[:maxcrit]
    warning "Max connections reached in MySQL: #{used_con} out of #{max_con}" if used >= config[:maxwarn]
    ok "Max connections is under limit in MySQL: #{used_con} out of #{max_con}"
  rescue Mysql2::Error => e
    critical "MySQL check failed: #{e.error}"
  ensure
    client&.close
  end
end
