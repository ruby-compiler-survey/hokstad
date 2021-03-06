# FIXME
# This is all kinds of non-standard, but for
# now I only need very basic enumeration over
# Array and Range.
#


class Enumerator

end

class ArrayEnumerator < Enumerator
  def initialize(ary)
    @ary = ary
    @pos = 0
  end

  def next
    if @pos < @ary.length
      @pos += 1
      return @ary[@pos]
    else
      return nil
    end
  end
end

# This is not a standard class. We do this because
# it's an easy way of getting basic Enumerator support
# without
class RangeEnumerator < Enumerator
  # FIXME: @bug if I use "range" as a argument name
  # it triggers the range constructor rewrite
  def initialize(r)
    @min = r.first
    @max = r.last
    rewind
  end

  def rewind
    @cur = @min
  end

  def next
    if @cur <= @max
      cur = @cur
      @cur += 1
      return cur
    else
      # FIXME: This is wrong, but for the correct behaviour
      # we need exception support.
      return nil
    end
  end
end
