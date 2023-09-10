// try import utils
import "wren_utils" for UTILS_VERSION, DMath

{
    var a = 50
    var b = 10.774
    System.write(DMath.subAbs(b, a))
}

{
    var a = 51
    var b = -10
    System.write(DMath.mulAbs(b, a))
}

{
    System.write("Utils: " + UTILS_VERSION)
}
