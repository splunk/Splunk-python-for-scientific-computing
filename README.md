## Python for Scientific Computing (PSC)

The Python for Scientific Computing app is an app that bundles Miniconda (a commercial binary distribution of Python) and some common Python libraries for scientific computing: numpy, scipy, pandas, scikit-learn, statsmodels.

This repo builds PSC for 4 platforms:
* Mac: https://splunkbase.splunk.com/app/2881/
* Linux 64-bit: https://splunkbase.splunk.com/app/2882/
* Windows 64-bit: https://splunkbase.splunk.com/app/2883/

### Running Native Unit Tests for Libraries in PSC
1. Build a PSC without removing ```nose``` library and ```tests``` files
    1. drop the ".skip" suffix in the nose package file name, e.g. ```darwin_x86_64/pkgs/nose-1.3.7-py27h2ee3cb8_2.tar.bz2.skip``` -> ```darwin_x86_64/pkgs/nose-1.3.7-py27h2ee3cb8_2.tar.bz2```
    2. run ```bash repack.sh```, automatically removes tests folders except networkx library's tests folder
    3. run ```bash build.sh```
2. Follow [NumPy/SciPy Testing Guidelines](https://github.com/numpy/numpy/blob/master/doc/TESTS.rst.txt) to run tests.
    1. To run SciPy's full test suite, use the following:
    ```python
    >>> import scipy
    >>> scipy.test()
    ```
    2. To run Numpy's full test suite, use the following:
    ```python
    >>> import numpy
    >>> numpy.test()
    ```

### Disabling Bundle Replication
PSC is not supposed to be bundle replicated in a Search Head Clustering environment, therefore, it must be added to ```distsearch.conf```
```
[replicationBlacklist]
noanaconda = apps[/\\]Splunk_SA_Scientific_Python*[/\\]...
```




