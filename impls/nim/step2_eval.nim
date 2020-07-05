import linenoise
import reader
import printer
import tables
import sugar
import types
import sequtils
import strformat

proc eval_ast(ast:MalNode,env:Table[string,MalNode]):MalNode

let repl_env = [("+",MalNode(kind:kProc,f:(x:int,y:int)=>x+y)),
            ("-",MalNode(kind:kProc,f:(x:int,y:int)=>x-y)),
            ("*",MalNode(kind:kProc,f:(x:int,y:int)=>x*y)),
            ("/",MalNode(kind:kProc,f:(x:int,y:int)=>x div y))].toTable

proc READ*(s:string):MalNode = read_str(s)
proc EVAL*(ast:MalNode):MalNode =
  case ast.kind
  of kList:
    if ast.lst.len==0:
      return ast
    else:
      let p = eval_ast(ast,repl_env)
      if p.lst[0].kind != kProc:
        raise newException(ValueError,"Can't apply type " & $ast.lst[0].kind )
      if p.lst.len != 3:
        raise newException(ValueError,"Wrong number of arguments")
      if (p.lst[1].kind != kNum ) or ( p.lst[2].kind != kNum ):
        raise newException(ValueError,&"Expected int,int got {p.lst[1].kind},{p.lst[2].kind}")
      return MalNode(kind:kNum,num:p.lst[0].f(p.lst[1].num,p.lst[2].num))
  else:
    return eval_ast(ast,repl_env)
      
proc PRINT*(s:MalNode):string = $s
proc rep*(s:string):string = s.READ.EVAL.PRINT

proc eval_ast(ast:MalNode,env:Table[string,MalNode]):MalNode =
  case ast.kind
  of kSym:
    return env[ast.str]#or a proc
  of kList,kVector:
    return MalNode(kind:kVector,lst:ast.lst.map(EVAL))
  of kTable:
    result = MalNode(kind:kTable)
    for k,v in ast.tab.pairs:
      result.tab.add(EVAL(k),EVAL(v))
  else:
    return ast

when isMainModule:
  proc main() =
    #linenoise history
    discard historySetMaxLen(100)
    discard historyLoad("history.txt")
    
    while true:
      let input = linenoise.readLine("user> ")
      if input == nil:
        echo "Bye"
        break
      let str_in = $input
      case str_in
      of "quit":
        echo "Toodles"
        break
      else:
        try:
          echo rep(str_in)
        except ValueError as e:
          echo e[].msg
      discard historyAdd(input)
      discard historySave("history.txt")
      linenoise.free(input)
  main()

