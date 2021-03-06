require 'active_support'

module RailsRefactor
  module Support
    class MigrationBuilder

      attr_accessor :file_name

      def self.reset_table_rename_memory
        @@rename_map = Hash.new
      end
      reset_table_rename_memory
      @@used_time_stamps = Hash.new(false)

      def initialize(migration_name)
        @rails_root = RAILS_ROOT
        @up_commands = Array.new
        @down_commands = Array.new
        @file_name = File.join(@rails_root, 'db', 'migrate', "#{unique_time_stamp}_#{migration_name.underscore}.rb")
        @migration_name = migration_name
      end

      def rename_table(from, to)
        old_table_name = table_name(from)
        new_table_name = table_name(to)
        @up_commands << "    rename_table(:#{old_table_name}, :#{new_table_name})"
        @down_commands << "    rename_table(:#{new_table_name}, :#{old_table_name})"
        @@rename_map[old_table_name] = new_table_name
      end

      def rename_column(table, from, to)
        table = renamed_table_name(table)
        @up_commands << "    rename_column(:#{table}, :#{from}, :#{to})"
        @down_commands << "    rename_column(:#{table}, :#{to}, :#{from})"
      end

      def save
        open(@file_name, "w") do |out|
          out.print migration_contents
        end
      end

      def to_s
        migration_contents
      end

      private

      def migration_contents
        <<-MIGRATION
class #{@migration_name} < ActiveRecord::Migration
  def self.up
#{@up_commands.join("\n")}
  end

  def self.down
#{@down_commands.join("\n")}
  end
end
        MIGRATION
      end

      def unique_time_stamp
        suggested = Time.now.strftime('%Y%m%d%H%M%S')
        while @@used_time_stamps[suggested]
          suggested = Time.now.strftime('%Y%m%d%H%M%S')
          sleep(1)
        end
        @@used_time_stamps[suggested] = true
        suggested
      end

      def table_name(value)
        value.gsub(/.*::/, '').pluralize
      end

      def renamed_table_name(name)
        name = table_name(name)
        if renamed_name = @@rename_map[name]
          renamed_name
        else
          name
        end
      end

    end
  end
end
