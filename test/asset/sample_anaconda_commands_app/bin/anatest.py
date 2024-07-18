import csv
import sys
import splunk.Intersplunk
import string

import exec_anaconda

exec_anaconda.exec_anaconda()

import numpy

if __name__ == "__main__":
    (isgetinfo, sys.argv) = splunk.Intersplunk.isGetInfo(sys.argv)

    if isgetinfo:
        splunk.Intersplunk.outputInfo(False, True, False, False, None, False)

    splunk.Intersplunk.readResults(None, None, True)
    results = [
        {
            "python_version": sys.version,
            "numpy_version": numpy.version.version,
            "sys.path": sys.path,
        }
    ]

    splunk.Intersplunk.outputResults(results, messages={})
