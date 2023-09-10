// hello!
System.write("Hello, world!")
System.write(System.clock)
System.write(Num.pi)

var a = 50
var b = 10
var c = a / 5

System.write(c)

var trees = ["cedar", "birch", "oak", "willow"]
System.write(trees[3])

import "random" for Random

var list_ll = []
var random = Random.new()
System.write(random.float())

var count = 3
var temp_o = 0
while (count != 0) {
    count = count - 1
    temp_o = random.float()
    list_ll.add(temp_o)
    System.write(temp_o)
}
System.write(list_ll.count)