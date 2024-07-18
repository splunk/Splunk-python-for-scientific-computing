import exec_anaconda

exec_anaconda.exec_anaconda()

import sys
import os

print(sys.path)


def test_lxml():
    import lxml.etree

    print(sys.version)
    print(lxml.__file__)


if __name__ == "__main__":
    import nose

    nose.runmodule()
