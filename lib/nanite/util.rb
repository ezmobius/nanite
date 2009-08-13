class String
  ##
  # Convert to snake case.
  #
  #   "FooBar".snake_case           #=> "foo_bar"
  #   "HeadlineCNNNews".snake_case  #=> "headline_cnn_news"
  #   "CNN".snake_case              #=> "cnn"
  #
  # @return [String] Receiver converted to snake case.
  #
  # @api public
  def snake_case
    return self.downcase if self =~ /^[A-Z]+$/
    self.gsub(/([A-Z]+)(?=[A-Z][a-z]?)|\B[A-Z]/, '_\&') =~ /_*(.*)/
    return $+.downcase
  end

  ##
  # Convert a constant name to a path, assuming a conventional structure.
  #
  #   "FooBar::Baz".to_const_path # => "foo_bar/baz"
  #
  # @return [String] Path to the file containing the constant named by receiver
  #   (constantized string), assuming a conventional structure.
  #
  # @api public
  def to_const_path
    snake_case.gsub(/::/, "/")
  end
end

class Object
  unless defined? instance_exec # 1.9 and 1.8.7
    module InstanceExecHelper; end
    include InstanceExecHelper

    # Evaluate the block with the given arguments within the context of
    # this object, so self is set to the method receiver.
    #
    # From Mauricio's http://eigenclass.org/hiki/bounded+space+instance_exec
    def instance_exec(*args, &block)
      begin
        old_critical, Thread.critical = Thread.critical, true
        n = 0
        n += 1 while respond_to?(method_name = "__instance_exec#{n}")
        InstanceExecMethods.module_eval { define_method(method_name, &block) }
      ensure
        Thread.critical = old_critical
      end

      begin
        send(method_name, *args)
      ensure
        InstanceExecMethods.module_eval { remove_method(method_name) } rescue nil
      end
    end
  end
end
