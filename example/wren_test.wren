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

var count = 1000
while (count != 0) {
    count = count - 1
    list_ll.add(random.float())
}
System.write(list_ll.count)