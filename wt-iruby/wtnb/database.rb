require "active_support/all"
require 'active_record'

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
    Record.connection.execute(sql)
  end

  # Timezone
  Time.zone = "UTC"
end
