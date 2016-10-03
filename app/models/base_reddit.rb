require_relative 'base'

class BaseReddit < Base
  attr_accessor :reddit_object

  def get_from_reddit(klass, list_attr, ended_at, after, limit, count)
    args = { limit: limit, count: count }
    if(after)
      args[:after] = after
    end
    list = klass.reddit_accessor(reddit_object, args)
    if (list.length > 0)
      list_attr = (list_attr + list.map do |item|
          klass.new(klass.constructor_args_for_reddit_object(self, item))
      end).uniq do |c|
        klass.unique_parent_child(self, c)
      end
      ended_at += limit
      after = list.last.fullname
    end
    return {ended_at: ended_at, after: after}
  end
end
