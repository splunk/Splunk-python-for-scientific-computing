import exec_anaconda
exec_anaconda.exec_anaconda()

import sys
import os
print sys.path

def test_openssl():
     import OpenSSL
     print OpenSSL.__file__

def test_splunk_rest():
     import splunk.rest

def test_requests():
    import requests
    url = "https://127.0.0.1:8089/servicesNS/nobody/system/storage/collections/data/SavedSearchHistory"
    r = requests.get(url, auth=("admin","changeme"), verify=False)
    print r.text

if __name__ == "__main__":
    import nose
    nose.runmodule()
