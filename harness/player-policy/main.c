#include "Redesigned/Player/SGRPlayerPolicy.h"
#include <assert.h>
#include <stdio.h>
int main(void) {
    assert(SGRPlayerTapFraction(25, 100, false) == .25);
    assert(SGRPlayerTapFraction(25, 100, true) == .75);
    assert(SGRPlayerTapFraction(-10, 100, false) == 0);
    assert(SGRPlayerTapFraction(110, 100, false) == 1);
    assert(isnan(SGRPlayerTapFraction(1, 0, false)));
    assert(isnan(SGRPlayerTapFraction(NAN, 100, false)));
    assert(!SGRPlayerShouldImmerse(true, 13.99, 10));
    assert(SGRPlayerShouldImmerse(true, 14, 10));
    assert(!SGRPlayerShouldImmerse(false, 20, 10));
    assert(!SGRPlayerShouldImmerse(true, NAN, 10));
    assert(!SGRPlayerShouldImmerse(true, 10, 20));
    puts("Player: bounded/RTL seeking and four-second idle policy passed");
}
