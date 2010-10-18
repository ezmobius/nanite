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

      def notify(method, options = {})
        if options[:on]
          notifications[options[:on]] ||= []
          notifications[options[:on]] << [self, method]
        else
          notifications[:_all] ||= []
          notifications[:_all] << [self, method]
        end
      end

      def trigger(event, arg = nil)
        events = (notifications[event] || [])
        events += (notifications[:_all] || [])
        events.each do |receiver, method|
          receiver.__send__(method, arg)
        end
      end
    end
  end
end
