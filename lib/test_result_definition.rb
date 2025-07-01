#!/usr/bin/env ruby

LKP_SRC ||= ENV['LKP_SRC'] || File.dirname(__dir__)

require "#{LKP_SRC}/lib/lkp_path"

class TestResultDefinition
  def initialize(definitions = nil)
    definitions ||= LKP::Path.src('etc', 'test-result-definition.yml')

    # {"pass"=>{"*"=>"pass"}, "fail"=>{"*"=>"fail failed", "xfstests"=>"crash crashed warn"}, "skip"=>{"*"=>"skip block", "xfstests"=>"inconsistent_fs"}}
    @definitions = definitions.instance_of?(Hash) ? definitions : YAML.load_file(definitions)

    regexps = @definitions.map do |type, hash|
      regexps = hash.map { |k, v| Regexp.new("^#{k == '*' ? '[^.]+' : k}\\.(.+\\.)*(#{v.split(' ').join('|')})$", true) }
      [type, Regexp.union(regexps)]
    end

    @regexps = Hash[regexps]

    instance_eval do
      @regexps.each do |type, regexp|
        define_singleton_method("#{type}?") do |stat|
          stat =~ regexp
        end
      end

      # rli9 FIXME: what if user specified result as definition key?
      define_singleton_method(:result?) do |stat|
        @result_regexp ||= Regexp.union(@regexps.values)

        stat =~ @result_regexp
      end
    end
  end

  def type(stat)
    return unless result?(stat)

    @regexps.find { |_type, regexp| stat =~ regexp }.first
  end

  def patterns(type, test)
    @definitions[type].select { |k, _v| ['*', test].include?(k) } # {"*"=>"fail failed", "xfstests"=>"crash crashed warn"}
                      .values
                      .flat_map { |v| v.split(' ') }
  end
end
