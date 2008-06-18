# Need to modify the inbuilt Module class, to catch const_missing calls.
class Module

  # New version of const_missing which catches requests made to the
  # Metaweb module/namespace - and generates modules to represent
  # data domains if necessary.
  def const_missing_with_freebase_support(class_id)
    if self.name[/^Freebase::Types/]
      new_freebase_type(class_id)
    else
      const_missing_without_freebase_support(class_id)
    end
  end
  
  alias_method_chain :const_missing, :freebase_support
  
end