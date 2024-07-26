#!/usr/bin/env ruby
require 'net/http'
require 'timeout'
require 'optparse'
require 'aws-sdk-s3'
require 'logger'
require 'json'
require 'thread'
require 'open3'

# Logging setup
$logger = Logger.new(STDOUT)
$logger.level = Logger::INFO

class String
  def red; "\e[31m#{self}\e[0m" end
end

class S3
  attr_reader :bucket, :domain, :code

  def initialize(bucket, timeout, logger)
    @bucket = bucket
    @domain = format('http://%s.s3.amazonaws.com', bucket)
    @timeout = timeout
    @logger = logger
  end

  def exists?
    code != 404
  end

  def code
    http && http.code.to_i
  end

  def aws_exists?
    s3 = Aws::S3::Client.new
    begin
      s3.head_bucket(bucket: @bucket)
      true
    rescue Aws::S3::Errors::NoSuchBucket
      false
    end
  end

  def run_aws_cli(actions)
    actions.each do |action|
      case action
      when 'copy'
        execute_aws_command("aws s3 cp s3://#{@bucket} s3://#{@bucket}-copy --recursive")
      when 'delete'
        execute_aws_command("aws s3 rm s3://#{@bucket} --recursive")
      when 'move'
        execute_aws_command("aws s3 mv s3://#{@bucket} s3://#{@bucket}-moved --recursive")
      when 'ls'
        execute_aws_command("aws s3 ls s3://#{@bucket}")
      else
        $logger.warn("Unknown action: #{action}")
      end
    end
  end

  private

  def http
    Timeout::timeout(@timeout) do
      @http ||= Net::HTTP.get_response(URI.parse(@domain))
    end
  rescue => e
    @logger.error("Error fetching #{@domain}: #{e.message}")
    nil
  end

  def execute_aws_command(command)
    stdout, stderr, status = Open3.capture3(command)
    if status.success?
      $logger.info("AWS CLI command successful: #{command}")
      $logger.info(stdout) unless stdout.empty?
    else
      $logger.error("AWS CLI command failed: #{command}")
      $logger.error(stderr) unless stderr.empty?
    end
  end
end

class Scanner
  def initialize(list, show_codes, timeout, threads, logger, rate_limit, actions)
    @list = list
    @show_codes = show_codes
    @timeout = timeout
    @threads = threads
    @logger = logger
    @results = []
    @results_mutex = Mutex.new
    @rate_limit = rate_limit
    @actions = actions
    @last_request_time = Time.now
  end

  def scan
    queue = Queue.new
    @list.each { |word| queue << word }

    workers = (0...@threads).map do
      Thread.new do
        while !queue.empty? && word = queue.pop(true) rescue nil
          sleep(rate_limited_sleep) # Rate limit

          bucket = S3.new(word, @timeout, @logger)
          if bucket.exists? && (@show_codes.empty? || @show_codes.include?(bucket.code))
            result = "#{bucket.bucket}.s3.amazonaws.com (#{bucket.code})"
            @logger.info("Found bucket: #{result}")
            @results_mutex.synchronize { @results << result }
            bucket.run_aws_cli(@actions) # Run AWS CLI commands
          end
        end
      end
    end

    workers.each(&:join)

    # Debugging line to check if results are collected
    $logger.info("Scan completed with #{@results.length} results")
  end

  def results
    @results
  end

  private

  def rate_limited_sleep
    now = Time.now
    elapsed = now - @last_request_time
    sleep_time = [0, (@rate_limit - elapsed)].max
    @last_request_time = now
    sleep_time
  end
end

class Wordlist
  ENVIRONMENTS = %w(dev development stage s3 staging prod production test)
  PERMUTATIONS = %i(permutation_raw permutation_envs permutation_host permutation_subdomain)

  class << self
    def generate(common_prefix, prefix_wordlist)
      [].tap do |list|
        PERMUTATIONS.each do |permutation|
          list << send(permutation, common_prefix, prefix_wordlist)
        end
      end.flatten.uniq
    end

    def from_file(prefix, file)
      generate(prefix, IO.read(file).split("\n"))
    end

    def permutation_raw(common_prefix, _prefix_wordlist)
      common_prefix
    end

    def permutation_envs(common_prefix, prefix_wordlist)
      [].tap do |permutations|
        prefix_wordlist.each do |word|
          ENVIRONMENTS.each do |environment|
            ['%s-%s-%s', '%s-%s.%s', '%s-%s%s', '%s.%s-%s', '%s.%s.%s'].each do |bucket_format|
              permutations << format(bucket_format, common_prefix, word, environment)
            end
          end
        end
      end
    end

    def permutation_host(common_prefix, prefix_wordlist)
      [].tap do |permutations|
        prefix_wordlist.each do |word|
          ['%s.%s', '%s-%s', '%s%s'].each do |bucket_format|
            permutations << format(bucket_format, common_prefix, word)
            permutations << format(bucket_format, word, common_prefix)
          end
        end
      end
    end

    def permutation_subdomain(common_prefix, prefix_wordlist)
      [].tap do |permutations|
        prefix_wordlist.each do |word|
          permutations << format('%s.%s', word, common_prefix)
        end
      end
    end
  end
end

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: scanner.rb [options]"

  opts.on("-f", "--file FILE", "File with common bucket prefixes") do |f|
    options[:file] = f
  end

  opts.on("-c", "--codes x,y,z", Array, "HTTP status codes to show") do |codes|
    options[:codes] = codes.map(&:to_i)
  end

  opts.on("-o", "--output FILE", "Output file to save results") do |output|
    options[:output] = output
  end

  opts.on("-s", "--timeout SECONDS", "Timeout for HTTP requests") do |timeout|
    options[:timeout] = timeout.to_i
  end

  opts.on("-T", "--threads COUNT", "Number of threads to use") do |threads|
    options[:threads] = threads.to_i
  end

  opts.on("-r", "--rate LIMIT", "Rate limit in seconds between requests") do |rate|
    options[:rate] = rate.to_i
  end

  opts.on("-a", "--actions x,y,z", Array, "AWS CLI actions to perform (copy, delete, move, ls)") do |actions|
    options[:actions] = actions
  end

  opts.on("-h", "--help", "Prints this help") do
    puts opts
    exit
  end
end.parse!

if options[:file].nil?
  $logger.error("Please provide a file with common bucket prefixes using -f or --file")
  exit
end

# Set default values for optional parameters
options[:timeout] ||= 5
options[:threads] ||= 10
options[:rate] ||= 1 # Default rate limit to 1 second
options[:actions] ||= [] # Default to no actions

wordlist = Wordlist.from_file(ARGV[0], options[:file])

$logger.info("Generated wordlist from file, #{wordlist.length} items...")

scanner = Scanner.new(wordlist, options[:codes] || [], options[:timeout], options[:threads], $logger, options[:rate], options[:actions])
scanner.scan

if options[:output]
  begin
    File.open(options[:output], 'w') do |file|
      $logger.info("Saving results to #{options[:output]}")
      scanner.results.each do |result|
        file.puts result
      end
    end
  rescue => e
    $logger.error("Failed to write to output file: #{e.message}")
  end
else
  $logger.info("No output file specified. Results will not be saved.")
end

