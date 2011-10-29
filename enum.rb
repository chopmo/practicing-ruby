module FakeEnumerable

  def map(&block)
    if block_given?
      result = []
      each { |e| result << block.call(e) }
      result
    else
      FakeEnumerator.new(self, :map)
    end
  end

  def select(&block)
    result = []
    each { |e| result << e if block.call(e) }
    result
  end

  def sort_by(&block)
    keys = map(&block)
    data_by_key = {}
    keys.zip(self).each { |k, v| data_by_key[k] = v }
    keys.sort.map { |k| data_by_key[k] }
  end

  def reduce(sym_or_acc = nil)
    acc = block_given? ? sym_or_acc : nil
    each do |e|
      if acc.nil?
        acc = e
      elsif block_given?
        acc = yield(acc, e)
      else
        acc = e.send(sym_or_acc, acc)
      end
    end
    acc
  end
end

class FakeEnumerator
  def initialize(data, sym)
    @data = data
    @sym = sym
    @idx = -1
  end

  def next
    @idx += 1
    i = 0
    @data.each do |e|
      return e if i == @idx
      i += 1
    end

    raise StopIteration 
  end

  def rewind
    @idx = -1
  end

  def with_index
    idx = -1
    @data.send(@sym) do |e|
      idx += 1
      yield(e, idx)
    end
  end
end

class SortedList
  include FakeEnumerable

  def initialize
    @data = []
  end

  def <<(new_element)
    @data << new_element
    @data.sort!

    self
  end

  def each
    if block_given?
      @data.each { |e| yield(e) }
    else
      FakeEnumerator.new(self, :each)
    end
  end
end

require "minitest/autorun"

describe "FakeEnumerable" do
  before do
    @list = SortedList.new

    # will get stored interally as 3,4,7,13,42
    @list << 3 << 13 << 42 << 4 << 7
  end

  it "supports map" do
    @list.map { |x| x + 1 }.must_equal([4,5,8,14,43]) 
  end

  it "supports sort_by" do
    # ascii sort order
    @list.sort_by { |x| x.to_s }.must_equal([13, 3, 4, 42, 7])
  end

  it "supports select" do
    @list.select { |x| x.even? }.must_equal([4,42])
  end

  it "supports reduce" do
    @list.reduce(:+).must_equal(69)
    @list.reduce { |s,e| s + e }.must_equal(69)
    @list.reduce(-10) { |s,e| s + e }.must_equal(59)
  end
end

describe "FakeEnumerator" do
  before do
    @list = SortedList.new

    @list << 3 << 13 << 42 << 4 << 7
  end

  it "supports next" do
    enum = @list.each

    enum.next.must_equal(3)
    enum.next.must_equal(4)
    enum.next.must_equal(7)
    enum.next.must_equal(13)
    enum.next.must_equal(42)

    assert_raises(StopIteration) { enum.next }
  end

  it "supports rewind" do
    enum = @list.each

    4.times { enum.next }
    enum.rewind

    2.times { enum.next }
    enum.next.must_equal(7)
  end

  it "supports with_index" do
    enum     = @list.map
    expected = ["0. 3", "1. 4", "2. 7", "3. 13", "4. 42"]  

    enum.with_index { |e,i| "#{i}. #{e}" }.must_equal(expected)
  end
end
