import linenoise
proc READ*(s:string):string = s
proc EVAL*(s:string):string = s
proc PRINT*(s:string):string = s
proc rep*(s:string):string = s.READ.EVAL.PRINT

when isMainModule:
  proc main() =
    while true:
      let input = readLine("user> ")
      if input == "quit\0":
        echo "Toodles"
        break
      if input==nil:
        echo "Bye"
        break
      echo rep($input)
      
  main()

