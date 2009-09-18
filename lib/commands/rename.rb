require 'find'
require 'rubygems'
require 'active_support'
require 'support/migration_builder'
require 'support/database'

module RailsRefactor
  module Commands
    class Rename

      IGNORE_DIRECTORIES = ['vendor', 'log', 'tmp', 'db']
      IGNORE_FILE_TYPES =  ['bin', 'git', 'svn', 'sh', 'swp', 'sql']
      FIND_PRUNE_REGEXP = Regexp.new(/((^\.\/(#{IGNORE_DIRECTORIES.join('|')}))|\.(#{IGNORE_FILE_TYPES.join('|')}))$/)

      def initialize(options = {})
        @scm = options[:scm]
        @execute = options[:execute]
        @migrate = options[:migrate]
        @db = Support::Database.new
      end

      def run(args)
        raise "incorrect arguments for rename: #{args}" if args.size != 2

        from, to = args
        @from_singular = from.singularize
        @from_plural = from.pluralize
        @to_singular = to.singularize
        @to_plural = to.pluralize

        rename_files
        rename_constants_and_variables

        if @migrate
          rename_tables
        end
      end

      private

      def rename_files
        renames = {
          "test/unit/#{@from_singular}_test.rb" => "test/unit/#{@to_singular}_test.rb",
          "test/functional/#{@from_plural}_controller_test.rb" => "test/functional/#{@to_plural}_controller_test.rb",
          "test/fixtures/#{@from_plural}.yml" => "test/fixtures/#{@to_plural}.yml",
          "app/models/#{@from_singular}.rb" => "app/models/#{@to_singular}.rb",
          "app/models/#{@from_singular}_sweeper.rb" => "app/models/#{@to_singular}_sweeper.rb",
          "app/helpers/#{@from_singular}_helper.rb" => "app/helpers/#{@to_singular}_helper.rb",
          "app/helpers/#{@from_plural}_helper.rb" => "app/helpers/#{@to_plural}_helper.rb",
          "app/controllers/#{@from_singular}_controller.rb" => "app/controllers/#{@to_singular}_controller.rb",
          "app/controllers/#{@from_plural}_controller.rb" => "app/controllers/#{@to_plural}_controller.rb",
          "app/views/#{@from_plural}" => "app/views/#{@to_plural}",
        }

        puts "Renaming files and directories:" unless @execute

        renames.each do |from, to|
          if File.exist?(from)
            if @execute
              @scm.move(from,to)
            else
              puts "  will rename #{from} -> #{to}"
            end
          end
        end
      end

      def rename_constants_and_variables
        replaces = {
          @from_singular => @to_singular,
          @from_plural => @to_plural,
          @from_singular.classify => @to_singular.classify,
          @from_plural.classify => @to_plural.classify,
        }
        replace_regexp = Regexp.new("(\\b|_)(#{replaces.keys.join("|")})(\\b|[_A-Z])")

        if @execute
          do_with_found_files do |content, path|
            content.gsub!(replace_regexp) {"#{$1}#{replaces[$2]}#{$3}"}
          end
        else
          puts "Will replacing the following constants and variables:"
          replaces.each do |f,t|
            puts "  #{f} -> #{t}"
          end
          puts "  -- listing matches for this regular expression: #{replace_regexp.to_s}"

          do_with_found_files do |content, path|
            content.each_with_index do |line, idx|
              line.strip!
              line.scan(replace_regexp).each do
                puts "  #{path}:#{idx+1}: #{line} "
                puts "    -> #{line.gsub(replace_regexp) {"#{$1}#{replaces[$2]}#{$3}"}}"
              end
            end
            false
          end
          puts
        end
      end

      def rename_tables
        if @db.table_exists?(@from_singular)
          migration_name = "Rename#{remove_namespace_seperator(@from_singular.classify.pluralize)}To#{remove_namespace_seperator(@to_plural.classify.pluralize)}"
          @migration_builder = Support::MigrationBuilder.new(migration_name)
          @migration_builder.rename_table(@from_plural, @to_plural)
          if @execute
            @migration_builder.save
          else
            puts "Generated the following migration:"
            puts @migration_builder.to_s
            puts ''
          end
        end
      end

      def rename_columns
        # TODO
      end

      def do_with_found_files
        Find.find(".") do |path|
          if path =~ FIND_PRUNE_REGEXP
            Find.prune
          else
            if File.file?(path)
              content = File.read(path)
              if replaced = yield(content, path)
                open(path, "w") do |out|
                out.print content
              end
            end
            end
          end
        end
      end

      def remove_namespace_seperator(value)
        value.sub('::', '')
      end

    end
  end
end