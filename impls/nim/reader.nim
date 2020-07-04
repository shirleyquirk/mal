import nre
import sequtils
import strutils
import parseutils
type
  MalKind* = enum
    MalSym,MalNum,MalString,MalList,MalVector,MalTable
  MalNode* = object
    case kind:MalKind
    of MalList,MalVector,MalTable:
      list:seq[MalNode]
    of MalSym:
      ident*:string
    of MalNum:
      num:int
    of MalString:
      str:string

  Token = string
  Reader = object
    tokens: seq[Token]
    position: int

#FAILING TESTS:
# 'x => (quote x)
# '(1 2 3) => (quote (1 2 3))
# `x => (quasiquote x)
# `(1 2 3) => (quasiquote (1 2 3))
# ~x => (unquote x)
# ~(1 2 3) => (unquote (1 2 3))
# ~@(1 2 3) => (splice-unquote (1 2 3))
# @a => (deref a)
# ^a b => (with-meta b a)

#----------forward decl------------#
proc read_form(r:var Reader):MalNode
proc read_list(r:var Reader):MalNode
proc read_atom(r:var Reader):MalNode
proc read_vector(r:var Reader):MalNode
proc read_table(r:var Reader):MalNode

proc next(r:var Reader):Token =
  result = r.tokens[r.position]
  inc r.position
proc peek(r:Reader):Token =
  r.tokens[r.position]
proc tokenize(s:string):Reader =
  let pattern = re"""[\s,]*(~@|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*\"?|;.*|[^(\s)\[\]{}('\"`,;)]*)"""
  result.tokens = s.findAll(pattern).mapIt(it.strip(true,true,{' ',','}))
  
proc `$`*(node:MalNode):string =
  case node.kind
  of MalSym:
    node.ident
  of MalNum:
    $node.num
  of MalString:#really take it out and then put it back?
    var replacements = @[("\\","\\\\"),
                        ("\"","\\\""),
                        ("\n","\\n"),
                        ("\r","\\r"),
                        ("\t","\\t"),
                        ("\a","\\a"),
                        ("\b","\\b"),
                        ("\f","\\f"),
                        ("\v","\\v")]
    for i in 0..6:
      replacements.add(($char(i),'\\' & $i))
    for i in 14..31:
      replacements.add(($char(i),"\\x" & toHex($char(i))))
    for i in 128..160:
      replacements.add(($char(i),"\\x" & toHex($char(i))))
    "\"" & node.str.multiReplace(replacements) & "\""
  of MalList:
    "(" & node.list.map(`$`).join(" ") & ")"
  of MalVector:
    "[" & node.list.map(`$`).join(" ") & "]"
  of MalTable:
    "{" & node.list.map(`$`).join(" ") & "}"
proc read_str*(s:string):MalNode =
  var reader = tokenize(s)
  reader.read_form()

template Magic(func_name:string):untyped =
  discard r.next()
  MalNode(kind:MalList,list: @[MalNode(kind:MalSym,ident:`func_name`),r.readform()])

proc dumpTokens(r:Reader):MalNode =
  result = MalNode(kind:MalList)
  for t in r.tokens:
    result.list.add(MalNode(kind:MalString,str:t))
proc withMeta(r:var Reader):MalNode =
  result = Magic("with-meta")
  result.list.insert(r.read_form(),1)
proc read_form(r:var Reader):MalNode =
  case r.peek
  of "(":   r.read_list()
  of "[":   r.read_vector()
  of "{":   r.read_table()
  of "'":   Magic("quote")
  of "`":   Magic("quasiquote")
  of "~":   Magic("unquote")
  of "~@":  Magic("splice-unquote")
  of "@":   Magic("deref")
  of "^":   r.withMeta()
  of "%":   r.dumpTokens()
  else:     r.read_atom()

template read_container(cont_kind:MalKind,close_sym:string):untyped =
  discard r.next()
  result = MalNode(kind:`cont_kind`)
  while true:
    case r.peek
      of "":
        raise newException(ValueError,"Expected \"" & `close_sym` & "\" but found EOF")
      of `close_sym`:
        discard r.next
        return
      else:
        result.list.add(r.read_form())
proc read_vector(r:var Reader):MalNode = read_container(MalVector,"]")
proc read_table(r:var Reader):MalNode = read_container(MalTable,"}")
proc read_list(r:var Reader):MalNode = read_container(MalList,")")
#  discard r.next()# '('
#  result = MalNode(kind:MalList)
#  while true:
#    case r.peek
#      of "":
#        raise newException(ValueError,"EOF")
#      of ")":
#        discard r.next
#        return
#      else:
#        result.list.add(r.read_form())

proc read_string(input:string):MalNode =
  #truly need a thingy if we do hex or unicode
  var str:string
  type stateEnum = enum
    normal,escaped,byte0,byte1
  var high_nibble:char
  var state:stateEnum
  for i in 1..<len(input):
    case state
    of escaped:
      state = normal
      case input[i]
      of 'n':
        str.add('\n')# == \x0a
      of 't':
        str.add('\t')# == \x09
      of 'a':
        str.add('\a')# == \x07 
      of 'r':
        str.add('\r')# == \x0d
      of 'b':
        str.add('\b')# == \x08
      of 'f':
        str.add('\f')# == \x0c
      of 'v':
        str.add('\v')# == \x0b
      of '0'..'9':# 0..9 => \0..\9   no `-` with char
        str.add(char(uint8(input[i])-uint8('0')))
      of 'x':#byte escape expects 2 chars
        state = byte0
      #of 'u':unicode escape expects 4 chars
      of '\\':
        str.add('\\')
      of '"':
        str.add('"')
      else:
        str.add("\\" & input[i])#sure why not
    of normal:
      case input[i]
      of '\\':
        state = escaped
      of '"':
        return MalNode(kind:MalString,str:str)
      else:
        str.add(input[i])
    of byte0:
      state = byte1
      case input[i]
      of '0'..'9','a'..'f','A'..'F':
        high_nibble = input[i]
      else:
        raise newException(ValueError,"Truncated \\xXX escape")
    of byte1:
      state = normal
      case input[i]
      of '0'..'9','a'..'f','A'..'F':
        str.add(char(fromHex[uint8](high_nibble & input[i])))
      else:
        raise newException(ValueError,"Truncated \\xXX escape")

  raise newException(ValueError,"Expected '\"' got EOF")

proc read_atom(r:var Reader):MalNode =
  let atom = cast[string](r.next())
  var intval:int
  if parseInt(atom,intval,0)!=0:
    MalNode(kind:MalNum,num:intval)
  elif atom[0]=='"':#string
    atom.read_string
  else:#identifier
    MalNode(kind:MalSym,ident:atom)

