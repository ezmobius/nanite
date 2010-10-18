# A local version of a notification system.
# Can notify parts of the system of events, e.g. a new agent registered.
module Nanite
  module Notifications
    module NotificationCenter
      def notifications
        @@notifications ||= {}
      end

      def clear_notifications
        notifications.clear
      end

      def register_notification(type, receiver, method)
        notifications[type] ||= []
        notifications[type] << [receiver, method]
      end

      def notify(method, options = {})
        if options[:on]
          register_notification(options[:on].to_sym, self, method)
        else
          register_notification(:_all, self, method)
        end
      end

      def trigger(event, *args)
        events = (notifications[event.to_sym] || [])
        events += (notifications[:_all] || [])
        results = events.collect do |receiver, method|
          case method
          when Symbol:
            receiver.__send__(method, *args)
          when Proc:
            method.call(*args)
          end
        end.collect {|result| !!result}

        !results.include?(false)
      end
    end
  end
end
