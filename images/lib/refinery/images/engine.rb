module Refinery
  module Images
    class Engine < ::Rails::Engine
      include Refinery::Engine

      isolate_namespace Refinery
      engine_name :refinery_images

      require 'aws-sdk'
      ::Aws.config.update({
                              region: ENV['S3_REGION'] ? ENV['S3_REGION'] : 'us-east-1',
                              credentials: ::Aws::Credentials.new(ENV['S3_KEY'], ENV['S3_SECRET']),
                          })
      S3_BUCKET = ::Aws::S3::Resource.new.bucket(ENV['S3_BUCKET'])

      config.autoload_paths += %W( #{config.root}/lib )

      initializer 'attach-refinery-images-with-dragonfly', :after => :load_config_initializers do |app|
        ::Refinery::Images::Dragonfly.configure!
        ::Refinery::Images::Dragonfly.attach!(app)
      end

      initializer "register refinery_images plugin" do
        Refinery::Plugin.register do |plugin|
          plugin.pathname = root
          plugin.name = 'refinery_images'
          plugin.version = %q{2.0.0}
          plugin.menu_match = %r{refinery/image(_dialog)?s$}
          plugin.activity = { :class_name => :'refinery/image' }
          plugin.url = proc { Refinery::Core::Engine.routes.url_helpers.admin_images_path }
        end
      end

      config.after_initialize do
        Refinery.register_extension(Refinery::Images)
      end
    end
  end
end
