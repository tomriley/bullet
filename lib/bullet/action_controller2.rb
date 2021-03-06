module Bullet
  class ActionController
    def self.enable
      require 'action_controller'
      if Rails.version =~ /\A2.3/
        ::ActionController::Dispatcher.middleware.use Bullet::Rack
        ::ActionController::Dispatcher.class_eval do
          class <<self
            alias_method :origin_reload_application, :reload_application
            def reload_application
              origin_reload_application
              Bullet.clear
            end
          end
        end
      elsif Rails.version =~ /\A2.[12]/
        ::ActionController::Dispatcher.class_eval do
          alias_method :origin_reload_application, :reload_application
          def reload_application
            origin_reload_application
            Bullet.clear
          end
        end

        ::ActionController::Base.class_eval do
          alias_method :origin_process, :process
          def process(request, response, method = :perform_action, *arguments)
            Bullet.start_request
            response = origin_process(request, response, method = :perform_action, *arguments)

            if Bullet.notification?
              if response.headers["type"] && response.headers["type"].include?('text/html') &&
                  response.body.include?("<html>") && response.body.include?("</html>")
                response.body <<= Bullet.gather_inline_notifications
                response.headers["Content-Length"] = response.body.length.to_s
              end

              Bullet.perform_out_of_channel_notifications
            end
            Bullet.end_request
            response
          end
        end
      else
        puts "Gem Bullet: Unsupported rails version"
      end
    end
  end
end
