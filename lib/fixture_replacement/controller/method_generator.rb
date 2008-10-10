module FixtureReplacementController
  class MethodGenerator
    
    class << self
      def generate_methods
        AttributeCollection.instances.each do |attributes_instance|
          new(attributes_instance).generate_methods
        end
      end
    end
    
    def initialize(object_attributes)
      @object_attributes = object_attributes
    end
    
    def generate_methods
      generate_default_method
      generate_new_method
      generate_create_method
      generate_attributes_method
    end
    
    def generate_default_method
      obj = @object_attributes
      
      ClassFactory.fixture_replacement_module.module_eval do
        define_method("default_#{obj.fixture_name}") do |*args|
          hash = args[0] || Hash.new
          DelayedEvaluationProc.new { 
            [obj, hash]
          }
        end
      end
    end
    
    def generate_create_method
      obj = @object_attributes
      
      ClassFactory.fixture_replacement_module.module_eval do
        define_method("create_#{obj.fixture_name}") do |*args|
          obj.to_created_class_instance(args[0], self)
        end
      end
    end
    
    def generate_new_method
      obj = @object_attributes
      
      ClassFactory.fixture_replacement_module.module_eval do
        define_method("new_#{obj.fixture_name}") do |*args|
          obj.to_new_class_instance(args[0], self)
        end
      end
    end
    
    # Generates +attributes_for_*+ methods which returns the
    # attributes given in example_data.rb as a hash.  If attribute
    # names are given to the generated method, only those
    # attributes are returned.
    def generate_attributes_method
      obj = @object_attributes

      ClassFactory.fixture_replacement_module.module_eval do
        define_method("attributes_for_#{obj.fixture_name}") do |*args|
          if args.size > 1
            obj.hash.slice(*args)
          else
            obj.hash
          end
        end
      end
    end
  end
end