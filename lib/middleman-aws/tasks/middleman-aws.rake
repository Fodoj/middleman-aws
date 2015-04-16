#------------------------------------------------------------------------
# Rakefile
#------------------------------------------------------------------------
require 'yaml'
require 'uri'

namespace :mm do

  desc 'Remove all files in the build directory'
  task :clobber do |t, args|
    # kill the old package dir
    rm_r 'build' rescue nil
  end

  desc 'Compile all files into the build directory'
  task :build do
    puts '## Compiling static pages'
    status = system 'bundle exec middleman build'
    puts status ? 'Build successful.' : 'Build failed.'
  end

  desc 'Deploy to S3 and invalidate Cloudfront after a Git commit/push'
  task :deploy do

    puts '## Deploy starting...'
    cd 'build' do
      # system 'git add .'
      system 'git add -u'
      message = "Site updated at #{Time.now}"
      puts "## Commiting: #{message}"
      system "git commit -m \"#{message}\""
      # puts "## Pushing generated website"
      # system "git push origin master"
      # puts "## Github Pages deploy complete"
    end

    credentials!
    aws_env = "AWS_ACCESS_KEY=#{credentials['access_key_id']} AWS_SECRET=#{credentials['secret_access_key']}"
    puts '## Syncing to S3...'
    system "#{aws_env} bundle exec middleman s3_sync"
    puts '## Invalidating cloudfront...'
    system "#{aws_env} bundle exec middleman invalidate"
    puts '## Deploy complete.'
  end

  desc 'One step clobber, build, deploy'
  task :publish => [:clobber, :build, :deploy] do
  end


  desc 'Run the preview server at http://localhost:4567'
  task :preview do
    system 'middleman server'
  end

  desc 'Show config'
  task :show_config do |t, args|

    credentials!

    puts "\n----------------------------------------------------------------------------------"
    puts 'Configuration:'
    puts "\t:working directory: #{Rake.original_dir}"
    puts "\t:project: #{project}"
    puts "\t:aws_secrets_file: #{aws_secrets_file}"
    puts "\t:access_key_id: #{credentials['access_key_id']}"
    puts "----------------------------------------------------------------------------------\n"
  end

  # validate file exists
  def credentials!
    unless File.exists?(aws_secrets_file)
      puts "\nWarning: Config file is missing: #{aws_secrets_file}.\nFile contents should look like:\naccess_key_id: XXXX\nsecret_access_key: XXXX\n\n."
    end

    access_key_id     = credentials.fetch('access_key_id') { ENV['AWS_ACCESS_KEY_ID'] }
    secret_access_key = credentials.fetch('secret_access_key') { ENV['AWS_SECRET_ACCESS_KEY'] }

    {
      access_key_id: access_key_id
      secret_access_key: secret_access_key
    }

  end

  # load from a user directory i.e. ~/.aws/acme.yml
  def credentials
    # load secrets from the user home directory
    @credentials ||= YAML::load_file(aws_secrets_file)
  end

  def aws_secrets_file
    File.expand_path("~/.aws/#{project}.yml")
  end

  def project
    File.basename(Rake.original_dir)
  end
end
