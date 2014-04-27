workers Integer(ENV['PUMA_WORKERS'] || 1)
threads Integer(ENV['MIN_THREADS'] || 1), Integer(ENV['MAX_THREADS'] || 1)

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  Sidekiq.configure_client do |config|
    config.redis = { :size => 2 }
  end

  Sidekiq.configure_server do |config|
    database_url = ENV['DATABASE_URL']
    if database_url
      ENV['DATABASE_URL'] = "#{database_url}?pool=18"
      ActiveRecord::Base.establish_connection
    end
  end

  @sidekiq_pid ||= spawn("bundle exec sidekiq -c 2")
end
