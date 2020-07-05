import types
import printer
import core

import nre
import sequtils
import strutils
import parseutils
import tables

type
  Token = string
  Reader = object
    tokens: seq[Token]
    position: int

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
  let pattern = re"""[\s,]*(~@|τ|[\[\]{}()'`~^@]|"(?:\\.|[^\\"])*\"?|;.*|[^(\s)\[\]{}('\"`,;)]*)"""
  result.tokens = s.findAll(pattern).mapIt(it.strip(true,true,{' ',','}))
  
proc read_str*(s:string):MalNode =
  var reader = tokenize(s)
  reader.read_form()

template Magic(func_name:string):untyped =
  discard r.next()
  MalNode(kind:kList,lst: @[MalNode(kind:kSym,str:`func_name`),r.readform()])

proc dumpTokens(r:var Reader):MalNode =
  discard r.next()
  result = MalNode(kind:kList)
  for t in r.tokens:
    result.lst.add(MalNode(kind:kString,str:t))
proc withMeta(r:var Reader):MalNode =
  result = Magic("with-meta")
  result.lst.insert(r.read_form(),1)

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
  of "τ":   r.dumpTokens()
  else:     r.read_atom()

template read_container(cont_kind:MalType,close_sym:string):untyped =
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
          result.lst.add(r.read_form())
proc read_vector(r:var Reader):MalNode = read_container(kVector,"]")

proc read_table_tmp(r:var Reader):MalNode = read_container(kList,"}")
proc read_table(r:var Reader):MalNode =
  let tmp = r.read_table_tmp.lst
  if ( tmp.len and 1 )==1:
    raise newException(ValueError,"Error: uneven number of objects in table")
  var pairs = newSeq[tuple[key:MalNode,val:MalNode]]()
  for i in countup(0,tmp.len-1,2):
    pairs.add((tmp[i],tmp[i+1]))

  MalNode(kind:kTable,tab: pairs.toTable)

proc read_list(r:var Reader):MalNode = 
  read_container(kList,")")

proc read_string(input:string):MalNode =
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
        return MalNode(kind:kString,str:str)
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
    MalNode(kind:kNum,num:intval)
  elif atom[0]=='"':#string
    atom.read_string
  else:#strifier
    MalNode(kind:kSym,str:atom)

