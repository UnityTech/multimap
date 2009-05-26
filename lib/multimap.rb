require 'multiset'

class Multimap < Hash
  class << self
    alias_method :hash_s_create, :[]
    private :hash_s_create

    def [](*args)
      return _create([], *args)
    end

    def _create(default = [], *args) #:nodoc:
      if args.size == 1 && args.first.is_a?(Hash)
        args[0] = args.first.inject({}) { |hash, (key, value)|
          unless value.is_a?(default.class)
            value = (default.dup << value)
          end
          hash[key] = value
          hash
        }
      else
        index = 0
        args.map! { |value|
          unless index % 2 == 0 || value.is_a?(default.class)
            value = (default.dup << value)
          end
          index += 1
          value
        }
      end

      map = hash_s_create(*args)
      map.default = default
      map
    end
    private :_create
  end

  def initialize(default = [])
    super
  end

  def initialize_copy(original) #:nodoc:
    super
    clear
    original.each_pair { |key, container| self[key] = container }
  end

  alias_method :hash_aref, :[]
  protected :hash_aref

  alias_method :hash_aset, :[]=
  private :hash_aset

  # call-seq:
  #   map[key] = value        => value
  #   map.store(key, value)   => value
  #
  # Associates the value given by <i>value</i> with the key
  # given by <i>key</i>. Unlike a regular hash, multiple can be
  # assoicated with the same value.
  #
  #   map = Multimap["a" => 100, "b" => 200]
  #   map["a"] = 9
  #   map["c"] = 4
  #   map   #=> {"a" => [100, 9], "b" => [200], "c" => [4]}
  def store(key, value)
    update_container(key) do |container|
      container << value
      container
    end
  end
  alias_method :[]=, :store

  # call-seq:
  #   map.delete(key, value)  => value
  #   map.delete(key)         => value
  #
  # Deletes and returns a key-value pair from <i>map</i>. If only
  # <i>key</i> is given, all the values matching that key will be
  # deleted.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.delete("b", 300) #=> 300
  #   map.delete("a")      #=> [100]
  def delete(key, value = nil)
    if value
      hash_aref(key).delete(value)
    else
      super(key)
    end
  end

  # call-seq:
  #   map.each { |key, value| block } => map
  #
  # Calls <i>block</i> for each key/value pair in <i>map</i>, passing
  # the key and value to the block as a two-element array.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each {|key, value| puts "#{key} is #{value}" }
  #
  # <em>produces:</em>
  #
  #   a is 100
  #   b is 200
  #   b is 300
  def each
    each_pair do |key, value|
      yield [key, value]
    end
  end

  # call-seq:
  #   map.each_key { |key| block } => map
  #
  # Calls <i>block</i> for each key in <i>hsh</i>, passing the key
  # as a parameter.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_key { |key| puts key }
  #
  # <em>produces:</em>
  #
  #   a
  #   b
  #   b
  def each_key
    each_pair_list do |key, values|
      yield key
    end
  end

  alias_method :hash_each_pair, :each_pair
  private :hash_each_pair

  alias_method :each_pair_list, :each_pair

  # call-seq:
  #   map.each_pair { |key_value_array| block } => map
  #
  # Calls <i>block</i> for each key/value pair in <i>map</i>,
  # passing the key and value as parameters.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_pair { |key, value| puts "#{key} is #{value}" }
  #
  # <em>produces:</em>
  #
  #   a is 100
  #   b is 200
  #   b is 300
  def each_pair
    each_pair_list do |key, values|
      values.each do |value|
        yield key, value
      end
    end
  end

  # call-seq:
  #   map.each_value { |value| block } => map
  #
  # Calls <i>block</i> for each key in <i>map</i>, passing the
  # value as a parameter.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.each_value { |value| puts value }
  #
  # <em>produces:</em>
  #
  #   100
  #   200
  #   300
  def each_value
    each_pair do |key, value|
      yield value
    end
  end

  def freeze #:nodoc:
    each_pair_list { |_, container| container.freeze }
    default.freeze
    super
  end

  # call-seq:
  #   map.has_value?(value)    => true or false
  #   map.value?(value)        => true or false
  #
  # Returns <tt>true</tt> if the given value is present for any key
  # in <i>map</i>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.has_value?(300)   #=> true
  #   map.has_value?(999)   #=> false
  def has_value?(value)
    values.include?(value)
  end
  alias_method :value?, :has_value?

  # call-seq:
  #   map.index(value)    => key
  #
  # Returns the key for a given value. If not found, returns
  # <tt>nil</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.index(100)   #=> "a"
  #   map.index(200)   #=> "b"
  #   map.index(999)   #=> nil
  def index(value)
    invert[value]
  end

  # call-seq:
  #   map.replace(other_map) => map
  #
  # Replaces the contents of <i>map</i> with the contents of
  # <i>other_map</i>.
  #
  #   map = Multimap["a" => 100, "b" => 200]
  #   map.replace({ "c" => 300, "d" => 400 })
  #   #=> Multimap["c" => 300, "d" => 400]
  def replace(other)
    case other
    when Array, Hash
      super(self.class.send(:_create, self.default, other))
    when self.class
      super
    else
      raise ArgumentError
    end
  end

  # call-seq:
  #   map.invert => multimap
  #
  # Returns a new multimap created by using <i>map</i>'s values as keys,
  # and the keys as values.
  #
  #   map = Multimap["n" => 100, "m" => 100, "d" => [200, 300]]
  #   map.invert #=> Multimap[100 => ["n", "m"], 200 => "d", 300 => "d"]
  def invert
    h = Multimap.new(default.dup)
    each_pair { |key, value| h[value] = key }
    h
  end

  alias_method :hash_keys, :keys
  private :hash_keys

  # call-seq:
  #   map.keys    => multiset
  #
  # Returns a new +Multiset+ populated with the keys from this hash. See also
  # <tt>Multimap#values</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.keys   #=> Multiset.new(["a", "b", "b", "c"])
  def keys
    keys = Multiset.new
    each_key { |key| keys << key }
    keys
  end

  # call-seq:
  #   map.length    =>  fixnum
  #   map.size      =>  fixnum
  #
  # Returns the number of key-value pairs in the map.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.length        #=> 4
  #   map.delete("a")   #=> 100
  #   map.length        #=> 3
  def size
    values.size
  end
  alias_method :length, :size

  # call-seq:
  #   map.merge(other_map) => multimap
  #
  # Returns a new multimap containing the contents of <i>other_map</i> and
  # the contents of <i>map</i>.
  #
  #   map1 = Multimap["a" => 100, "b" => 200]
  #   map2 = Multimap["a" => 254, "c" => 300]
  #   map2.merge(map2) #=> Multimap["a" => 100, "b" => [200, 254], "c" => 300]
  #   map1             #=> Multimap["a" => 100, "b" => 200]
  def merge(other)
    dup.update(other)
  end

  # call-seq:
  #   map.merge!(other_map)    => multimap
  #   map.update(other_map)    => multimap
  #
  # Adds each pair from <i>other_map</i> to <i>map</i>.
  #
  #   map1 = Multimap["a" => 100, "b" => 200]
  #   map2 = Multimap["b" => 254, "c" => 300]
  #
  #   map1.merge!(map2)
  #   #=> Multimap["a" => 100, "b" => [200, 254], "c" => 300]
  def update(other)
    case other
    when Hash
      other.each_pair do |key, values|
        update_container(key) do |container|
          if values.respond_to?(:each)
            values.each { |value| container << value }
          else
            container << values
          end
          container
        end
      end
    else
      raise ArgumentError
    end

    self
  end
  alias_method :merge!, :update

  # call-seq:
  #   map.select { |key, value| block }   => multimap
  #
  # Returns a new Multimap consisting of the pairs for which the
  # block returns true.
  #
  #   map = Multimap["a" => 100, "b" => 200, "c" => 300]
  #   map.select { |k,v| k > "a" }  #=> Multimap["b" => 200, "c" => 300]
  #   map.select { |k,v| v < 200 }  #=> Multimap["a" => 100]
  def select
    inject(self.class.new) { |map, (key, value)|
      map[key] = value if yield([key, value])
      map
    }
  end

  # call-seq:
  #   map.to_a => array
  #
  # Converts <i>map</i> to a nested array of [<i>key,
  # value</i>] arrays.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300], "c" => 400]
  #   map.to_a   #=> [["a", 100], ["b", 200], ["b", 300], ["c", 400]]
  def to_a
    ary = []
    each_pair do |key, value|
      ary << [key, value]
    end
    ary
  end

  # call-seq:
  #   map.to_hash => hash
  #
  # Converts <i>map</i> to a basic hash.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.to_hash   #=> { "a" => [100], "b" => [200, 300] }
  def to_hash
    dup
  end

  def lists
    lists = []
    each_pair_list { |key, container| lists << container }
    lists
  end

  # call-seq:
  #   map.values    => array
  #
  # Returns a new array populated with the values from <i>map</i>. See
  # also <tt>Multimap#keys</tt>.
  #
  #   map = Multimap["a" => 100, "b" => [200, 300]]
  #   map.values   #=> [100, 200, 300]
  def values
    values = []
    each_value { |value| values << value }
    values
  end

  protected
    def update_container(key) #:nodoc:
      container = hash_aref(key)
      container = container.dup if container.equal?(default)
      container = yield(container)
      hash_aset(key, container)
    end
end
