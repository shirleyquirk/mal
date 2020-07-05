import types
import tables
import sequtils
#core functions
iterator couples[T](l:openarray[T]):tuple[key:T,value:T] =
  var idx = 0
  while idx < len(l)-1:
    yield (l[idx],l[idx+1])

proc hash_map*(n:MalNode):MalNode =
  #takes a container and returns a hash-map
  case n.kind
  of kList,kVector:
    if (n.lst.len and 2) == 1:
      raise newException(ValueError,"Error: hashmaps require even number of arguments")
    result = MalNode(kind:kTable)
    #let tmp = toSeq(couples(n.lst))
    result.tab = initTable[MalNode,MalNode]()
    for k,v in couples(n.lst):
      result.tab.add(k,v)
  else:
    raise newException(ValueError,"Error: tried to make hashmap from non-collection")
