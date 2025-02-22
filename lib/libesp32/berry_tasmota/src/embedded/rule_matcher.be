#- Native code used for testing and code solidification -#
#- Do not use it directly -#

#@ solidify:Rule_Matcher_Key
#@ solidify:Rule_Matcher_Wildcard
#@ solidify:Rule_Matcher_Operator
#@ solidify:Rule_Matcher_Array
#@ solidify:Rule_Matcher


#-
# tests

tasmota.Rule_Matcher.parse("AA#BB#CC")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='CC'>]

tasmota.Rule_Matcher.parse("AA")
# [<Matcher key='AA'>]

tasmota.Rule_Matcher.parse("AA#BB#CC=2")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='CC'>, <Matcher op '=' val='2'>]

tasmota.Rule_Matcher.parse("AA#BB#CC>=3.5")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='CC'>, <Matcher op '>=' val='3.5'>]

tasmota.Rule_Matcher.parse("AA#BB#CC!3.5")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='CC!3.5'>]

tasmota.Rule_Matcher.parse("AA#BB#CC==3=5")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='CC'>, <Matcher op '==' val='3=5'>]

tasmota.Rule_Matcher.parse("AA#BB#!CC!==3=5")
# [<Matcher key='AA'>, <Matcher key='BB'>, <Matcher key='!CC'>, <Matcher op '!==' val='3=5'>]

tasmota.Rule_Matcher.parse("")
# []

tasmota.Rule_Matcher.parse("A#?#B")
# [<Matcher key='A'>, <Matcher any>, <Matcher key='B'>]

tasmota.Rule_Matcher.parse("A#?>50")
# [<Matcher key='A'>, <Matcher any>, <Matcher op '>' val='50'>]

tasmota.Rule_Matcher.parse("A[1]")
# [<instance: Rule_Matcher_Key()>, <Matcher [0]>]

tasmota.Rule_Matcher.parse("A[1]#B[2]>3")
# [<instance: Rule_Matcher_Key()>, <Matcher [0]>, <instance: Rule_Matcher_Key()>, <Matcher [0]>, <Matcher op '>' val='3'>]

tasmota.Rule_Matcher.parse("A#B[]>3")
# [<instance: Rule_Matcher_Key()>, <instance: Rule_Matcher_Key()>, <Matcher [0]>, <Matcher op '>' val='3'>]

#################################################################################

m = tasmota.Rule_Matcher.parse("AA")
assert(m.match({'aa':1}) == 1)
assert(m.match({'AA':'1'}) == '1')
assert(m.match({'ab':1}) == nil)

m = tasmota.Rule_Matcher.parse("AA#BB")
assert(m.match({'aa':1}) == nil)
assert(m.match({'aa':{'bb':1}}) == 1)

m = tasmota.Rule_Matcher.parse("AA#BB#CC=2")
assert(m.match({'aa':1}) == nil)
assert(m.match({'aa':{'bb':1}}) == nil)
assert(m.match({'aa':{'bb':{'cc':1}}}) == nil)
assert(m.match({'aa':{'bb':{'cc':2}}}) == 2)

m = tasmota.Rule_Matcher.parse("AA#?#CC=2")
assert(m.match({'aa':1}) == nil)
assert(m.match({'aa':{'bb':{'cc':2}}}) == 2)

m = tasmota.Rule_Matcher.parse("AA#Power[1]")
assert(m.match({'aa':{'power':[0.5,1.5,2.5]}}) == 0.5)
m = tasmota.Rule_Matcher.parse("AA#Power[2]")
assert(m.match({'aa':{'power':[0.5,1.5,2.5]}}) == 1.5)
m = tasmota.Rule_Matcher.parse("AA#Power[3]")
assert(m.match({'aa':{'power':[0.5,1.5,2.5]}}) == 2.5)
m = tasmota.Rule_Matcher.parse("AA#Power[4]")
assert(m.match({'aa':{'power':[0.5,1.5,2.5]}}) == nil)

m = tasmota.Rule_Matcher.parse("AA#Power[1]>1")
assert(m.match({'aa':{'power':[0.5,1.5,2.5]}}) == nil)
assert(m.match({'aa':{'power':[1.2,1.5,2.5]}}) == 1.2)

-#

class Rule_Matcher
  
  # We don't actually need a superclass, just implementing `match(val)`
  #
  # static class Rule_Matcher
  #   def init()
  #   end

  #   # return the next index in tha val string
  #   # or `nil` if no match
  #   def match(val)
  #     return nil
  #   end
  # end

  # Each matcher is an instance that implements `match(val) -> any or nil`
  #
  # The method takes a map or value as input, applies the matcher and
  # returns a new map or value, or `nil` if the matcher did not match anything.
  #
  # Example:
  #   Payload#?#Temperature>50
  # is decomposed as:
  #   <instance match="Payload">, <instance match_any>, <instance match="Temperature", <instance op='>' val='50'>
  #
  # Instance types:
  #     Rule_Matcher_Key(key): checks that the input map contains the key (case insensitive) and
  #                            returns the sub-value or `nil` if the key does not exist
  #
  #     Rule_Matcher_Wildcard: maps any key, which yields to unpredictable behavior if the map
  #                            has multiple keys (gets the first key returned by the iterator)
  #
  #     Rule_Matcher_Operator: checks is a simple value (numerical or string) matches the operator and the value
  #                            returns the value unchanged if match, or `nil` if no match

  static class Rule_Matcher_Key
    var name                                # literal name of what to match

    def init(name)
      self.name = name
    end

    # find a key in map, case insensitive, return actual key or nil if not found
    static def find_key_i(m, keyi)
      import string
      var keyu = string.toupper(keyi)
      if isinstance(m, map)
        for k:m.keys()
          if string.toupper(k)==keyu
            return k
          end
        end
      end
    end

    def match(val)
      if val == nil                 return nil end        # safeguard
      if !isinstance(val, map)      return nil end        # literal name can only match a map key
      var k = self.find_key_i(val, self.name)
      if k == nil             return nil end        # no key with value self.name
      return val[k]
    end

    def tostring()
      return "<Matcher key='" + str(self.name) + "'>"
    end
  end

  static class Rule_Matcher_Array
    var index                                # index in the array, defaults to zero

    def init(index)
      self.index = index
    end

    def match(val)
      if val == nil                 return nil end        # safeguard
      if !isinstance(val, list)     return val end        # ignore index if not a list
      if self.index <= 0            return nil end        # out of bounds
      if self.index > size(val)     return nil end        # out of bounds
      return val[self.index - 1]
    end

    def tostring()
      return "<Matcher [" + str(self.index) + "]>"
    end
  end

  static class Rule_Matcher_Wildcard

    def match(val)
      if val == nil               return nil end        # safeguard
      if !isinstance(val, map)    return nil end        # literal name can only match a map key
      if size(val) == 0           return nil end
      return val.iter()()                               # get first value from iterator
    end

    def tostring()
      return "<Matcher any>"
    end
  end

  static class Rule_Matcher_Operator
    var op_func                                         # function making the comparison
    var op_str                                          # name of the operator like '>'
    var op_value                                        # value to compare agains

    def init(op_func, op_value, op_str)
      self.op_func = op_func
      self.op_value = op_value
      self.op_str = op_str
    end

    def match(val)
      var t = type(val)
      if t != 'int' && t != 'real' && t != 'string'   return nil end  # must be a simple type
      return self.op_func(val, self.op_value) ? val : nil
    end

    def tostring()
      return "<Matcher op '" + self.op_str + "' val='" + str(self.op_value) + "'>"
    end
  end

  ###########################################################################################
  # instance variables
  var rule                  # original pattern of the rules
  var trigger               # rule pattern of trigger, excluding operator check (ex: "AA#BB>50" would be "AA#BB")
  var matchers              # array of Rule_Matcher(s)

  def init(rule, trigger, matchers)
    self.rule = rule
    self.trigger = trigger
    self.matchers = matchers
  end

  # parses a rule pattern and creates a list of Rule_Matcher(s)
  static def parse(pattern)
    import string
    if pattern == nil     return nil end
    
    var matchers = []

    # changes "Dimmer>50" to ['Dimmer', '>', '50']
    # Ex: DS18B20#Temperature<20
    var op_list = tasmota.find_op(pattern)

    # ex: 'DS18B20#Temperature'
    var value_str = op_list[0]
    var op_str = op_list[1]
    var op_value = op_list[2]

    var sz = size(value_str)
    var idx_start = 0                           # index of current cursor
    var idx_end = -1                            # end of current item

    while idx_start < sz
      # split by '#'
      var idx_sep = string.find(value_str, '#', idx_start)
      var item_str
      if idx_sep >= 0
        if idx_sep == idx_start   raise "pattern_error", "empty pattern not allowed" end
        item_str = value_str[idx_start .. idx_sep - 1]
        idx_start = idx_sep + 1
      else
        item_str = value_str[idx_start .. ]
        idx_start = sz              # will end the loop
      end

      # check if there is an array accessor
      var arr_start = string.find(item_str, '[')
      var arr_index = nil
      if arr_start >= 0             # we have an array index
        var arr_end = string.find(item_str, ']', arr_start)
        if arr_end < 0    raise "value_error", "missing ']' in rule pattern" end
        var arr_str = item_str[arr_start + 1 .. arr_end - 1]
        item_str = item_str[0 .. arr_start - 1]           # truncate
        arr_index = int(arr_str)
      end

      if item_str == '?'
        matchers.push(_class.Rule_Matcher_Wildcard())
      else
        matchers.push(_class.Rule_Matcher_Key(item_str))
      end

      if arr_index != nil
        matchers.push(_class.Rule_Matcher_Array(arr_index))
      end
    end

    # if an operator was found, add the operator matcher
    if op_str != nil && op_value != nil         # we have an operator
      var op_func = _class.op_parse(op_str)
      if op_func
        matchers.push(_class.Rule_Matcher_Operator(op_func, op_value, op_str))
      end
    end

    return _class(pattern, value_str, matchers)       # `_class` is a reference to the Rule_Matcher class
  end

  # apply all matchers, abort if any returns `nil`
  def match(val_in)
    if self.matchers == nil  return nil end
    var val = val_in

    var idx = 0
    while idx < size(self.matchers)
      val = self.matchers[idx].match(val)
      if val == nil     return nil end
      idx += 1
    end

    return val
  end

  def tostring()
    return str(self.matchers)
  end

  ###########################################################################################
  # Functions to compare two values
  ###########################################################################################
  static def op_parse(op)

    def op_eq_str(a,b)     return str(a)  == str(b)    end
    def op_neq_str(a,b)    return str(a)  != str(b)    end
    def op_eq(a,b)         return real(a) == real(b)   end
    def op_neq(a,b)        return real(a) != real(b)   end
    def op_gt(a,b)         return real(a) >  real(b)   end
    def op_gte(a,b)        return real(a) >= real(b)   end
    def op_lt(a,b)         return real(a) <  real(b)   end
    def op_lte(a,b)        return real(a) <= real(b)   end

    if   op=='=='           return op_eq_str
    elif op=='!=='          return op_neq_str
    elif op=='='            return op_eq
    elif op=='!='           return op_neq
    elif op=='>'            return op_gt
    elif op=='>='           return op_gte
    elif op=='<'            return op_lt
    elif op=='<='           return op_lte
    end
  end
end
