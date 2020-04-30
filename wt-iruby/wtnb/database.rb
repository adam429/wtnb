require "active_support/all"
require 'active_record'
require 'moneta'

module WTCube
  class Record < ActiveRecord::Base
      self.inheritance_column = 'ar_type'

      def read_attribute(attr_name, &block)
        name = attr_name.to_s
        name = self.class.attribute_aliases[name] || name

        _read_attribute(name, &block)
      end
  end

  # ----------- exec_sql ----------------
  def exec_sql(sql)
    ActiveRecord::Base.connection.execute(sql)
  end


  class Store
    class << self
      def __init()
        @store = Moneta.new(:File, dir: 'store')
      end

      def []=(key,obj)
        @store[key] = Marshal.dump(obj)
      end

      def [](key)
        obj = @store[key]
        if obj then
          Marshal.load(obj)
        else
          nil
        end
      end
    end
    self.__init()
  end


  def method_missing(m,*args,&block)
    return super if m.to_s=="to_hash"
    return super if m.to_s=="to_io"
    return super if m.to_s=="to_str"
    return super if m.to_s=="load_iseq"
    return super if m.to_s=="to_ary"
    return super if m.to_s=="to_int"

    item = Store[m.to_s]
    if item!=nil then
      item
    else
      super
    end
  end
end
