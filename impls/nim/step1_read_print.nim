import linenoise
import reader
import printer
import tables
proc READ*(s:string):MalNode = read_str(s)
proc EVAL*(s:MalNode):MalNode = s
proc PRINT*(s:MalNode):string = $s
proc rep*(s:string):string = s.READ.EVAL.PRINT

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

