import tables,hashes

type
  MalType* = enum
    kSym,kNum,kString,kList,kVector,kTable,kKeyword,kNil,kTrue,kFalse
  MalNode* = object
    case kind*:MalType
    of kList,kVector:         lst*:seq[MalNode]
    of kTable:                tab*:Table[MalNode,MalNode]
    of kSym,kKeyword,kString: str*:string
    of kNum:                  num*:int
    of kNil,kTrue,kFalse :    nil

proc hash*(node:MalNode):Hash

proc `==`*(a,b:MalNode):bool =
  if a.kind != b.kind:
    return false
  case a.kind:
    of kList,kVector:          a.lst == b.lst
    of kTable:                 a.tab == b.tab
    of kSym,kKeyword,kString:  a.str == b.str
    of kNum:                   a.num == b.num
    of kNil,kTrue,kFalse:      true


proc hash*(node:MalNode):Hash =
  result = hash(node.kind)
  case node.kind
  of kList,kVector:
    result = result !& hash(node.lst)
  of kTable:
    for k,v in node.tab.pairs:
      result = result !& hash(k)
      result = result !& hash(v)
  of kSym,kKeyword,kString:
    result = result !& hash(node.str)
  of kNum:
    result = result !& hash(node.num)
  of kNil,kTrue,kFalse: discard
  result = !$result

when isMainModule:
  import printer,reader
  let a = MalNode(kind:kNum,num:1)
  let b = MalNode(kind:kNum,num:2)
  let c = MalNode(kind:kNum,num:2)
  assert a != b
  assert b == c
  let d = MalNode(kind:kTable,tab: @[(a,b)].toTable)
  echo d
  let e = read_str("{ 1 2 }")
  echo e
  
