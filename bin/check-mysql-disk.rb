#!/usr/bin/env ruby
# frozen_string_literal: true

require 'mysql2'
require 'sensu-plugin/check/cli'

class CheckMysqlDisk < Sensu::Plugin::Check::CLI
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

  option :size,
         short: '-s VALUE',
         long: '--size=VALUE',
         description: 'Database size',
         proc: proc(&:to_f)

  option :warn,
         short: '-w VALUE',
         long: '--warning=VALUE',
         description: 'Warning threshold',
         proc: proc(&:to_f),
         default: 85

  option :crit,
         short: '-c VALUE',
         long: '--critical=VALUE',
         description: 'Critical threshold',
         proc: proc(&:to_f),
         default: 95

  def run
    client = Mysql2::Client.new(host: config[:hostname], username: config[:user], password: config[:password], port: config[:port], database: config[:database], socket: config[:socket])

    target_size = config[:size] || client.query('SELECT @@innodb_buffer_pool_size/1024/1024/1024 as dbsize').first['dbsize'].to_f

    results = client.query <<-SQL
      SELECT TABLE_SCHEMA,
      count(*) 'tables',
      concat(round(sum(table_rows)/1000000,2),'M') 'rows',
      round(sum(data_length)/(1024*1024*1024),2) 'data',
      round(sum(index_length)/(1024*1024*1024),2) 'idx',
      round(sum(data_length+index_length)/(1024*1024*1024),2) 'total_size',
      round(sum(index_length)/sum(data_length),2) 'idxfrac'
      FROM information_schema.TABLES GROUP BY TABLE_SCHEMA
    SQL

    total_size = results.inject(0.0) { |sum, row| sum + row['total_size'].to_f }

    disk_use_percentage = total_size / target_size * 100
    diskstr = "DB size: #{total_size.round(2)}GB, disk use: #{disk_use_percentage.round(2)}%"

    if disk_use_percentage > config[:crit]
      critical "Database size exceeds critical threshold: #{diskstr}"
    elsif disk_use_percentage > config[:warn]
      warning "Database size exceeds warning threshold: #{diskstr}"
    else
      ok diskstr
    end
  rescue Mysql2::Error => e
    critical "MySQL check failed: #{e.error}"
  ensure
    client&.close
  end
end
