class FixtureReplacementGenerator

  class << self
    def generate_methods(mod=FixtureReplacement)
      mod.instance_methods.each do |method|          
        if method =~ /(.*)_attributes/
          generator = new($1, mod)          
          generator.generate_default_method
          generator.generate_new_method
          generator.generate_create_method
        end
      end
    end
    
    # This uses a DelayedEvaluationProc, not a typical proc, for type checking.
    # It may be absurd to try to store a proc in a database, but even if someone tries,
    # they won't get an error from FixtureReplacement, since the error would be incredibly unclear
    def merge_unevaluated_method(obj, method_for_instantiation, hash={})
      hash.each do |key, value|
        if value.kind_of?(DelayedEvaluationProc)
          model_name, args = value.call
          hash[key] = obj.send("#{method_for_instantiation}_#{model_name}", args)
        end
      end
    end
  end
  
  attr_reader :model_name
  attr_reader :model_class
  attr_reader :fixture_module
  
  def initialize(method_name, fixture_mod=::FixtureReplacement)
    @model_name = method_name
    @model_class = method_name.camelize
    @fixture_module = fixture_mod
    
    add_to_class_singleton(@model_class)
  end
  
  def generate_default_method
    model_as_string = model_name
    default_method = "default_#{model_name}".to_sym

    fixture_module.module_eval do
      define_method(default_method) do |*args|
        DelayedEvaluationProc.new do
          [model_as_string, *args]
        end
      end
    end
  end
  
  def generate_create_method
    new_method = "new_#{model_name}".to_sym
    create_method = "create_#{model_name}".to_sym
    attributes_method = "#{model_name}_attributes".to_sym
    class_name = @model_name.to_class
    
    fixture_module.module_eval do
      define_method(create_method) do |*args|          
        hash_given = args[0] || Hash.new
        merged_hash = self.send(attributes_method).merge(hash_given)
        evaluated_hash = FixtureReplacementGenerator.merge_unevaluated_method(self, :create, merged_hash)        
        
        # we are NOT doing the following, because of attr_protected:
        #   obj = class_name.create!(evaluated_hash)
        obj = class_name.new
        evaluated_hash.each { |key, value| obj.send("#{key}=", value) }
        obj.save!
        obj          
      end
    end
  end
  
  def generate_new_method
    new_method = "new_#{model_name}".to_sym
    attributes_method = "#{model_name}_attributes".to_sym
    class_name = @model_name.to_class

    fixture_module.module_eval do
      define_method new_method do |*args|
        hash_given = args[0] || Hash.new
        merged_hash = self.send(attributes_method).merge(hash_given)
        evaluated_hash = FixtureReplacementGenerator.merge_unevaluated_method(self, :create, merged_hash)
        
        # we are also doing the following because of attr_protected:
        obj = class_name.new
        evaluated_hash.each { |key, value| obj.send("#{key}=", value) }
        obj
      end
    end
  end
  
private

  def add_to_class_singleton(obj)
    string = self.class.const_get(@model_class)

    model_name.instance_eval <<-HERE
      def to_class
        #{string}
      end
    HERE
  end
  
end
