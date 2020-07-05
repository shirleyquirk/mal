import types
import tables
import strutils
import sequtils
import strformat

proc pr_str*(tree:MalNode):string = $tree

proc prettify(s:string):string =
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
  s.multiReplace(replacements)
template surround(a:string,b,c:char):string =
  `b` & a & `c`
template print_container(prefix,suffix:char):string =
  surround(node.lst.mapIt($it).join(" "),prefix,suffix)

proc `$`*(node:MalNode):string =
  case node.kind
  of kSym:
    node.str
  of kKeyword: node.str[2..^1]
  of kNum:     $node.num
  of kString:  node.str.prettify.surround('"','"')
  of kList:    print_container('(',')')
  of kVector:  print_container('[',']')
  of kTable:
    block:
      var res = "{"
      for k,v in node.tab.pairs:
        res.add(&"{k} {v} ")
      if res.len==1:
        res.add('}')
      else:
        res[^1] = '}'
      res
  of kNil:    "nil"
  of kTrue:   "true"
  of kFalse:  "false"
  of kProc:   "<procedure>"

when isMainModule:
  import reader
  let test_str = """[ 1 "2" "\\n" ( blam "\\xff" { "5" 9 } ) ]"""
  assert test_str == $read_str(test_str)
