#include "dummy.hh"

#include <nexus/test.hh>

int @PROJECT_NAMESPACE@::foo() { return 10; }

TEST("foo == 10")
{
    CHECK(@PROJECT_NAMESPACE@::foo() == 10);
}
